// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Column_Primitives
public import Shared_Primitive
public import Storage_Generational_Primitives
public import Store_Primitive
public import Dictionary_Primitive
public import Dictionary_Ordered_Primitive
public import Dictionary_Ordered_Primitives
public import Hash_Indexed_Primitive
public import Buffer_Linear_Primitive
public import Stack_Primitive

/// A dynamically-growing keyed tree with dictionary-indexed children.
///
/// `Tree.Keyed<Key, Value>` is the general-purpose keyed tree primitive. Each node
/// stores a value and a set of children indexed by unique keys. It provides O(1)
/// child lookup by key, O(1) parent navigation, and O(d) key-path reconstruction.
///
/// ## Example
///
/// ```swift
/// var tree = Tree.Keyed<String, Int>()
/// let root = try tree.insert(0, at: .root)
/// let child = try tree.insert(1, at: .child(of: root, key: "left"))
/// let grandchild = try tree.insert(2, at: .child(of: child, key: "inner"))
///
/// tree.forEachPreOrder { value in
///     print(value)  // 0, 1, 2
/// }
/// ```
///
/// ## Generational Column Storage
///
/// Uses `Shared<Node, Column.Generational<Node>>` for storage — nodes live in a
/// sparse handle-validated slot column (`Storage.Generational`) with per-slot
/// generation tokens and free-slot recycling. Nodes reference each other by
/// generational `Handle` rather than pointer. Growth is explicit: when the column
/// is full the tree calls the generation-preserving relocating door (`grow(to:)`),
/// which retires the old pool wholesale and continues the incarnation history
/// index-aligned — outstanding positions survive growth.
///
/// Public `Tree.Position` tokens project the slot's generation into `UInt32`
/// (`UInt32(truncatingIfNeeded:)`): a token wraps after 2^32 frees of one slot
/// — equivalent to the retired arena's UInt32 token wrap.
///
/// ## Dictionary-Indexed Children
///
/// Each node's children are stored in an ordered hashed dictionary column
/// (`Dictionary<Shared<Hash.Entry<Key, Handle>, Hash.Indexed<…>>>.Ordered`),
/// providing O(1) keyed lookup and ordered iteration in insertion order.
///
/// ## Move-Only Support
///
/// Both the tree and its values can be `~Copyable`:
///
/// ```swift
/// struct FileHandle: ~Copyable { ... }
/// var handles = Tree.Keyed<String, FileHandle>()
/// let root = try handles.insert(FileHandle(), at: .root)
/// ```
///
/// ## Copy-on-Write
///
/// When `Value` is `Copyable`, `Tree.Keyed` uses copy-on-write semantics:
/// copies share storage until mutation, providing efficient value semantics.
/// The CoW machinery is the ratified `Shared` column (the W5 tower design): the
/// stored generational column rides a refcounted box whose uniqueness gate
/// (`withUnique`) runs before every mutation, and whose clone strategy is the
/// GENERATION-PRESERVING deep copy — positions minted before a CoW detach keep
/// resolving on both sides of the split.
extension Tree where Element: ~Copyable {

    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Keyed<Key: Hash.`Protocol`>: ~Copyable {

        /// The value stored at each node. Equivalent to the tree's `Element` type.
        public typealias Value = Element

        // MARK: - Typealiases

        /// Errors that can occur during keyed tree operations.
        public typealias Error = __TreeKeyedError<Key>

        /// Specifies where to insert a new node.
        public typealias InsertPosition = __TreeKeyedInsertPosition<Key>

        /// Typed node count.
        public typealias Count = Index<Node>.Count

        /// The ordered keyed-children column: an insertion-ordered hashed
        /// dictionary mapping child keys to node handles. The `Shared` (CoW)
        /// column flavor — `Key` and `Handle` are always `Copyable`, so the
        /// clone strategy is captured unconditionally and per-node child tables
        /// detach lazily when a CoW'd tree mutates them.
        public typealias Children = Dictionary_Primitive.Dictionary<
            Shared_Primitive.Shared<
                Hash.Entry<Key, Store.Generational.Handle>,
                Hash.Indexed<Column.Heap<Hash.Entry<Key, Store.Generational.Handle>>>
            >
        >.Ordered

        // MARK: - Node

        /// A node in the generational-column keyed tree.
        @frozen
        public struct Node: ~Copyable {
            /// The value stored in this node.
            public var value: Value
            /// Children indexed by key. Ordered hashed dictionary column for
            /// O(1) lookup with insertion-order iteration.
            public var _children: Children
            /// Handle of parent (nil for root).
            public var parentHandle: Store.Generational.Handle?
            /// Key under which this node is stored in its parent's children (nil for root).
            public var parentKey: Key?

            @inlinable
            public init(
                value: consuming Value,
                parentHandle: Store.Generational.Handle? = nil,
                parentKey: Key? = nil
            ) {
                self.value = value
                self._children = Children()
                self.parentHandle = parentHandle
                self.parentKey = parentKey
            }
        }

        // MARK: - Storage

        /// The node column: the generational slot store behind the `Shared` CoW box.
        /// Copyability flows from the column (`Shared<Node, B>` is `Copyable` iff
        /// `Node` is, and `Node` iff `Element`) — the S5 chain.
        @usableFromInline
        var _storage: Shared<Node, Column.Generational<Node>>

        /// Slot → live handle side table for decoding public `Tree.Position` values
        /// (a position carries only `(slot, UInt32 token)`; handles cannot be minted
        /// outside the column, so the tree records the handle of every occupied slot).
        /// Sized to the column's capacity; `nil` marks a free slot.
        @usableFromInline
        var _handles: Swift.Array<Store.Generational.Handle?>

        /// Handle of root node (nil if empty).
        @usableFromInline
        var _rootHandle: Store.Generational.Handle?

        // MARK: - Initialization
        //
        // The construction twins split on element copyability via MEMBER-LEVEL
        // where-clauses (SE-0267): `Shared`'s constructors split on element
        // copyability — the `Copyable` twin captures the column's
        // generation-preserving clone strategy so a shared box can restore
        // uniqueness; the `~Copyable` twin captures none. EXTENSION-level twins
        // are NOT usable here: on a nested-in-extension inverse-generic type the
        // extension signature canonicalizes the Copyable requirement away and
        // both inits mangle identically. At `Copyable` call sites the
        // more-constrained twin wins.

        /// Creates an empty keyed tree (move-only values).
        @inlinable
        public init() {
            self._storage = Shared(Column.Generational<Node>.create(slotCapacity: 1))
            self._handles = Swift.Array(repeating: nil, count: 1)
            self._rootHandle = nil
        }

        /// Creates a tree with a single root node (move-only values).
        ///
        /// - Parameter rootValue: The value for the root node.
        @inlinable
        public init(rootValue: consuming Value) {
            self.init()
            self._rootHandle = _insert(node: Node(value: rootValue))
        }

        /// Creates an empty keyed tree with reserved capacity (move-only values).
        ///
        /// - Parameter minimumCapacity: The minimum number of nodes to reserve space for.
        @inlinable
        public init(minimumCapacity: Count) {
            let capacity = Swift.max(Int(bitPattern: minimumCapacity), 1)
            self._storage = Shared(Column.Generational<Node>.create(slotCapacity: capacity))
            self._handles = Swift.Array(repeating: nil, count: capacity)
            self._rootHandle = nil
        }

        /// Creates an empty keyed tree (CoW-capable column; the clone strategy
        /// is captured here — the Copyable construction twin).
        @inlinable
        public init() where Element: Copyable {
            self._storage = Shared(Column.Generational<Node>.create(slotCapacity: 1))
            self._handles = Swift.Array(repeating: nil, count: 1)
            self._rootHandle = nil
        }

        /// Creates a tree with a single root node (CoW-capable column; the clone
        /// strategy is captured here — the Copyable construction twin).
        ///
        /// - Parameter rootValue: The value for the root node.
        @inlinable
        public init(rootValue: consuming Value) where Element: Copyable {
            self.init()
            self._rootHandle = _insert(node: Node(value: rootValue))
        }

        /// Creates an empty keyed tree with reserved capacity (CoW-capable
        /// column; the clone strategy is captured here — the Copyable construction twin).
        ///
        /// - Parameter minimumCapacity: The minimum number of nodes to reserve space for.
        @inlinable
        public init(minimumCapacity: Count) where Element: Copyable {
            let capacity = Swift.max(Int(bitPattern: minimumCapacity), 1)
            self._storage = Shared(Column.Generational<Node>.create(slotCapacity: capacity))
            self._handles = Swift.Array(repeating: nil, count: capacity)
            self._rootHandle = nil
        }

        // MARK: - Properties

        /// The number of nodes in the tree.
        @inlinable
        public var count: Count { _storage.withColumn { $0.count } }

        /// Whether the tree is empty.
        @inlinable
        public var isEmpty: Bool { _storage.withColumn { $0.isEmpty } }

        /// The position of the root node, or `nil` if the tree is empty.
        @inlinable
        public var root: Tree.Position? {
            guard let rootHandle = _rootHandle else { return nil }
            return _position(of: rootHandle)
        }

        // MARK: - Handle Plumbing

        /// Mints the public position for a live handle: the slot plus the slot
        /// generation projected into the position's `UInt32` token (wraps after
        /// 2^32 frees of one slot — the retired arena's wrap, unchanged).
        @inlinable
        func _position(of handle: Store.Generational.Handle) -> Tree.Position {
            Tree.Position(index: handle.index, token: UInt32(truncatingIfNeeded: handle.generation))
        }

        /// Decodes a public position into the live handle for its slot.
        ///
        /// Token validation provides O(1) safety checking:
        /// - Stale positions (after removal) are detected and rejected
        /// - No node memory is accessed without validation
        @usableFromInline
        func _handle(_ position: Tree.Position) throws(__TreeKeyedError<Key>) -> Store.Generational.Handle {
            let slot = Int(bitPattern: position.index)
            guard
                slot >= 0,
                slot < _handles.count,
                let handle = _handles[slot],
                UInt32(truncatingIfNeeded: handle.generation) == position.token,
                _storage.withColumn({ $0.contains(handle) })
            else { throw .invalidPosition }
            return handle
        }

        /// Validates that a position refers to a currently-occupied slot.
        @usableFromInline
        func _validate(_ position: Tree.Position) throws(__TreeKeyedError<Key>) {
            _ = try _handle(position)
        }

        /// Inserts a node into the column, growing first when full (the explicit
        /// `grow(to:)` door — positions survive growth by its contract), and
        /// records the minted handle in the side table.
        @inlinable
        mutating func _insert(node: consuming Node) -> Store.Generational.Handle {
            let handle = _storage.withUnique(consuming: node) { (column, node) -> Store.Generational.Handle in
                if column.count == column.capacity {
                    let doubled = Index<Node>.Count(UInt(2 &* Int(bitPattern: column.capacity)))
                    column.grow(to: doubled)
                }
                return column.insert(node)
            }
            let capacity = Int(bitPattern: _storage.capacity)
            while _handles.count < capacity {
                _handles.append(nil)
            }
            _handles[handle.index] = handle
            return handle
        }

        /// Removes the node at a live handle, clearing its side-table entry.
        @inlinable
        mutating func _remove(_ handle: Store.Generational.Handle) -> Node {
            guard let node = _storage.withUnique({ $0.remove(handle) }) else {
                // Unreachable: callers pass decoded live handles and no removal interleaves.
                preconditionFailure("Tree.Keyed: live handle failed to resolve on removal")
            }
            _handles[handle.index] = nil
            return node
        }

        /// Reads the node at a live handle via a borrowing closure.
        @inlinable
        func _node<R>(_ handle: Store.Generational.Handle, _ body: (borrowing Node) -> R) -> R {
            _storage.withColumn { body($0[handle]) }
        }

        /// Snapshots a node's children as `(key, handle)` pairs in insertion order.
        @inlinable
        func _children(of handle: Store.Generational.Handle) -> [(key: Key, handle: Store.Generational.Handle)] {
            _storage.withColumn { column in
                var out: [(key: Key, handle: Store.Generational.Handle)] = []
                column[handle]._children.forEach { key, child in
                    out.append((key, child))
                }
                return out
            }
        }

        /// Looks up the child handle under `key`, or nil.
        @inlinable
        func _childHandle(
            of handle: Store.Generational.Handle, key: Key
        ) -> Store.Generational.Handle? {
            _storage.withColumn { $0[handle]._children.withValue(forKey: key) { $0 } }
        }

        /// Links `child` under `parent` at `key` (the parent's child table mutates
        /// in place; its own CoW column detaches lazily if shared).
        @inlinable
        mutating func _link(parent: Store.Generational.Handle, key: Key, child: Store.Generational.Handle) {
            _storage.withUnique { _ = $0[parent]._children.insert(key: key, value: child) }
        }

        /// Unlinks the child under `key` from `parent`.
        @inlinable
        mutating func _unlink(parent: Store.Generational.Handle, key: Key) {
            _storage.withUnique { _ = $0[parent]._children.removeValue(forKey: key) }
        }
    }
}

// MARK: - Insert Operations (~Copyable)

extension Tree.Keyed where Element: ~Copyable {

    /// Inserts a value at the specified position.
    ///
    /// - Parameters:
    ///   - value: The value to insert.
    ///   - position: Where to insert the value.
    /// - Returns: The position of the newly inserted node (with token for validation).
    /// - Throws: ``Error/rootOccupied`` if inserting at root when it exists,
    ///           ``Error/invalidPosition`` if the parent position is invalid or stale,
    ///           ``Error/keyOccupied(_:)`` if the child key already exists at the parent.
    @inlinable
    @discardableResult
    public mutating func insert(
        _ value: consuming Value,
        at position: InsertPosition
    ) throws(__TreeKeyedError<Key>) -> Tree.Position {
        switch position {
        case .root:
            guard _rootHandle == nil else {
                throw .rootOccupied
            }
            let handle = _insert(node: Node(value: value))
            _rootHandle = handle
            return _position(of: handle)

        case .child(of: let parent, let key):
            let parentHandle = try _handle(parent)
            // Check child key is not already occupied
            let occupied = _storage.withColumn { $0[parentHandle]._children.contains(key: key) }
            guard !occupied else {
                throw .keyOccupied(key)
            }
            // Insert (may grow — the handle stays valid across growth by the
            // grow(to:) door's incarnation-history contract)
            let handle = _insert(node: Node(value: value, parentHandle: parentHandle, parentKey: key))
            _link(parent: parentHandle, key: key, child: handle)
            return _position(of: handle)
        }
    }

    /// Removes the leaf node at the specified position.
    ///
    /// - Parameter position: The position of the node to remove. Must be a leaf.
    /// - Returns: The value that was stored at the position.
    /// - Throws: ``Error/invalidPosition`` if the position is invalid or stale,
    ///           ``Error/cannotRemoveNonLeaf`` if the node has children.
    @inlinable
    @discardableResult
    public mutating func remove(at position: Tree.Position) throws(__TreeKeyedError<Key>) -> Value {
        let handle = try _handle(position)

        guard _node(handle, { $0._children.isEmpty }) else {
            throw .cannotRemoveNonLeaf
        }

        // Update parent's child dictionary
        let parentLink = _node(handle) { ($0.parentHandle, $0.parentKey) }
        if let parentHandle = parentLink.0, let parentKey = parentLink.1 {
            _unlink(parent: parentHandle, key: parentKey)
        } else {
            _rootHandle = nil
        }

        let node = _remove(handle)
        return node.value
    }

    /// Removes the subtree rooted at the specified position.
    ///
    /// All nodes in the subtree are removed and their values are deinitialized
    /// in post-order (children before parents).
    ///
    /// - Parameter position: The position of the root of the subtree to remove.
    /// - Throws: ``Error/invalidPosition`` if the position is invalid or stale.
    @inlinable
    public mutating func removeSubtree(at position: Tree.Position) throws(__TreeKeyedError<Key>) {
        let handle = try _handle(position)

        // Update parent's child dictionary
        let parentLink = _node(handle) { ($0.parentHandle, $0.parentKey) }
        if let parentHandle = parentLink.0, let parentKey = parentLink.1 {
            _unlink(parent: parentHandle, key: parentKey)
        } else {
            _rootHandle = nil
        }

        // Iterative post-order removal using explicit stack
        var pending = Stack<Store.Generational.Handle>()
        var visited = Stack<Store.Generational.Handle>()

        pending.push(handle)

        // Phase 1: Build reverse-post-order via pre-order push
        while !pending.isEmpty {
            let current = pending.pop()!
            visited.push(current)

            for (_, child) in _children(of: current) {
                pending.push(child)
            }
        }

        // Phase 2: Free in post-order (reverse of pre-order)
        while !visited.isEmpty {
            let current = visited.pop()!
            _ = _remove(current)
        }
    }

    /// Accesses the value at the specified position via a borrowing closure.
    ///
    /// - Parameters:
    ///   - position: The position of the node.
    ///   - body: A closure that receives a borrowing reference to the value.
    /// - Returns: The value returned by `body`, or `nil` if the position is invalid or stale.
    @inlinable
    public func peek<R>(at position: Tree.Position, _ body: (borrowing Value) -> R) -> R? {
        guard let handle = try? _handle(position) else { return nil }
        return _storage.withColumn { body($0[handle].value) }
    }

    /// Clears all nodes from the tree.
    @inlinable
    public mutating func clear() {
        _storage.withUnique { $0.removeAll() }
        for index in _handles.indices {
            _handles[index] = nil
        }
        _rootHandle = nil
    }

    /// Computes the height of the tree.
    ///
    /// The height is the length of the longest path from the root to a leaf.
    /// An empty tree returns `nil`, a single-node tree has height `.zero`.
    ///
    /// Uses iterative traversal to avoid stack overflow on deep trees.
    @inlinable
    public var height: Count? {
        guard let rootHandle = _rootHandle else { return nil }

        var maxHeight: Count = .zero
        var pending = Stack<(handle: Store.Generational.Handle, depth: Count)>()
        pending.push((rootHandle, .zero))

        while !pending.isEmpty {
            let (handle, depth) = pending.pop()!
            maxHeight = Swift.max(maxHeight, depth)

            for (_, child) in _children(of: handle) {
                pending.push((child, depth + .one))
            }
        }

        return maxHeight
    }
}

// MARK: - Copyable Value Extensions

extension Tree.Keyed where Element: Copyable {

    /// The root node's value, or nil if the tree is empty.
    ///
    /// Setting to a non-nil value updates the root (or creates it if empty).
    /// Setting to nil is a no-op — the setter exists for optional chaining
    /// writeback (e.g. `tree.rootValue?.field = x`). To set a sparse tree's
    /// root value to `Optional.none`, use the sparse subscript:
    /// `tree[[] as [Key]] = nil`.
    @inlinable
    public var rootValue: Value? {
        get {
            guard let rootHandle = _rootHandle else { return nil }
            return _node(rootHandle) { $0.value }
        }
        set {
            guard let newValue else { return }
            if let rootHandle = _rootHandle {
                _storage.withUnique { $0[rootHandle].value = newValue }
            } else {
                _rootHandle = _insert(node: Node(value: newValue))
            }
        }
    }

    /// Inserts a value at the specified position (CoW-aware).
    ///
    /// Uniqueness is restored by the `withUnique` gate inside each storage
    /// mutation, so a tree sharing its column with a copy detaches before writing.
    @inlinable
    @discardableResult
    public mutating func insert(
        _ value: Value,
        at position: InsertPosition
    ) throws(__TreeKeyedError<Key>) -> Tree.Position {
        switch position {
        case .root:
            guard _rootHandle == nil else {
                throw .rootOccupied
            }
            let handle = _insert(node: Node(value: value))
            _rootHandle = handle
            return _position(of: handle)

        case .child(of: let parent, let key):
            let parentHandle = try _handle(parent)
            let occupied = _storage.withColumn { $0[parentHandle]._children.contains(key: key) }
            guard !occupied else {
                throw .keyOccupied(key)
            }
            let handle = _insert(node: Node(value: value, parentHandle: parentHandle, parentKey: key))
            _link(parent: parentHandle, key: key, child: handle)
            return _position(of: handle)
        }
    }

    /// Returns the value at the specified position.
    ///
    /// - Parameter position: The position of the node.
    /// - Returns: The value at the position, or `nil` if invalid or stale.
    @inlinable
    public func peek(at position: Tree.Position) -> Value? {
        guard let handle = try? _handle(position) else { return nil }
        return _node(handle) { $0.value }
    }

    /// Replaces the value at the specified position.
    ///
    /// - Parameters:
    ///   - position: The position of the node.
    ///   - newValue: The new value.
    /// - Throws: ``Error/invalidPosition`` if the position is invalid or stale.
    @inlinable
    public mutating func update(at position: Tree.Position, _ newValue: Value) throws(__TreeKeyedError<Key>) {
        let handle = try _handle(position)
        _storage.withUnique { $0[handle].value = newValue }
    }
}

// MARK: - Conditional Copyable

extension Tree.Keyed.Node: Copyable where Element: Copyable {}
extension Tree.Keyed: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Tree.Keyed: @unsafe @unchecked Sendable where Key: Sendable, Element: Sendable {}
