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

public import Dictionary_Ordered_Primitives
public import Index_Primitives
public import Storage_Generational_Primitives
public import Store_Primitive
public import Tree_Primitives_Core

/// A dynamically-growing keyed tree with dictionary-indexed children.
///
/// `Tree.Keyed<Key>` is the general-purpose keyed tree primitive. Each node stores
/// a value and a set of children indexed by unique keys. It provides O(1) child
/// lookup by key, O(1) parent navigation, and O(d) key-path reconstruction.
///
/// It is the keyed ``Tree/Protocol`` conformer: the generational arena, decode
/// (Round M B2), token validation, typed counts (A3), the position-survives-growth
/// contract, and the shared insert / remove / navigation / traversal algorithms
/// live in ``Tree/Storage`` + the ``Tree/Protocol`` defaults. This type supplies
/// the ``__TreeKeyedLinks`` child-link representation (the ordered keyed-children
/// column plus the `parentKey` back-key) and its six key-addressed link witnesses.
///
/// ## Example
///
/// ```swift
/// var tree = Tree<Int>.Keyed<String>()
/// let root = try tree.insert(0, at: .root)
/// let child = try tree.insert(1, at: .child(of: root, key: "left"))
/// let grandchild = try tree.insert(2, at: .child(of: child, key: "inner"))
///
/// tree.forEachPreOrder { value in
///     print(value)  // 0, 1, 2
/// }
/// ```
///
/// ## Storage
///
/// The arena is ``Tree/Storage`` over the ``__TreeKeyedLinks`` child links: nodes
/// live in a generational slot column behind the `Shared` CoW box, referenced by
/// generational `Handle` rather than pointer. Growth is the explicit
/// generation-preserving relocating door (`grow(to:)`) — outstanding positions
/// survive growth. Public `Tree.Position` tokens project the slot's generation into
/// `UInt32` (wraps after 2^32 frees of one slot).
///
/// Each node's children are stored in an ordered hashed dictionary column,
/// providing O(1) keyed lookup and ordered iteration in insertion order; the
/// `parentKey` back-key gives O(1) unlink.
///
/// ## Move-Only Support
///
/// Both the tree and its values can be `~Copyable`:
///
/// ```swift
/// struct FileHandle: ~Copyable { ... }
/// var handles = Tree<FileHandle>.Keyed<String>()
/// let root = try handles.insert(FileHandle(), at: .root)
/// ```
///
/// ## Copy-on-Write
///
/// When `Value` is `Copyable`, `Tree.Keyed` is copy-on-write: copies share the
/// generational column behind the `Shared` CoW box until mutation. The clone
/// strategy is the GENERATION-PRESERVING deep copy, so a position minted before a
/// CoW detach keeps resolving on both sides of the split.
extension Tree where Element: ~Copyable {

    // Conforms to the hoisted `__TreeProtocol` (the `Tree.Protocol` surfacing): the
    // `.Protocol` typealias spelling collides with the metatype keyword in a
    // conformance clause, so the hoisted name is named directly here (as `Tree` and
    // `Tree.N` do).
    public struct Keyed<Key: Hash.`Protocol`>: ~Copyable, __TreeProtocol {

        /// The value stored at each node.
        ///
        /// Equivalent to the tree's `Element` type.
        public typealias Value = Element

        // MARK: - Typealiases

        /// How a child is addressed within its parent: a unique key.
        public typealias Address = Key

        /// Errors that can occur during the keyed tree's keyed-specific operations
        /// (`insert` / `update`).
        ///
        /// Shape-agnostic operations (`remove` / `removeSubtree` / `validate`) throw
        /// the shared ``Tree/Error``.
        public typealias Error = __TreeKeyedError<Key>

        /// Specifies where to insert a new node (keyed by `Key`).
        public typealias InsertPosition = __TreeKeyedInsertPosition<Key>

        /// Typed node count (A3).
        public typealias Count = Index<Element>.Count

        // MARK: - Storage

        /// The private generational arena.
        ///
        /// NON-PUBLIC — `@usableFromInline` for the inlinable witnesses; the
        /// `Tree.Protocol` defaults never reference it. The per-conformer child links
        /// are ``__TreeKeyedLinks`` — the ordered keyed-children column plus the
        /// `parentKey` back-key (A1: keeps the shared `__TreeNode` Key-agnostic).
        @usableFromInline
        var _storage: Storage<__TreeKeyedLinks<Key>>

        // MARK: - Initialization (MEMBER-LEVEL construction twins)
        //
        // The twins split on element copyability via MEMBER-LEVEL where-clauses
        // (SE-0267): the `Copyable` twin captures the column's generation-preserving
        // clone strategy via the `Tree.Storage` Copyable twin; the `~Copyable` twin
        // captures none. EXTENSION-level twins are NOT usable here — on a
        // nested-in-extension inverse-generic type the extension signature
        // canonicalizes the Copyable requirement away and both inits mangle
        // identically. At `Copyable` call sites the more-constrained twin wins.

        /// Creates an empty keyed tree (move-only values).
        @inlinable
        public init() { _storage = Storage<__TreeKeyedLinks<Key>>() }

        /// Creates a tree with a single root node (move-only values).
        ///
        /// - Parameter rootValue: The value for the root node.
        @inlinable
        public init(rootValue: consuming Value) {
            self.init()
            _rootHandle = _insertNode(rootValue, parent: nil)
        }

        /// Creates an empty keyed tree with reserved capacity (move-only values).
        @inlinable
        public init(minimumCapacity: Count) {
            _storage = Storage<__TreeKeyedLinks<Key>>(minimumCapacity: minimumCapacity)
        }

        /// Creates an empty CoW-capable keyed tree (the clone strategy is captured here).
        @inlinable
        public init() where Element: Copyable { _storage = Storage<__TreeKeyedLinks<Key>>() }

        /// Creates a CoW-capable tree with a single root node.
        ///
        /// - Parameter rootValue: The value for the root node.
        @inlinable
        public init(rootValue: consuming Value) where Element: Copyable {
            self.init()
            _rootHandle = _insertNode(rootValue, parent: nil)
        }

        /// Creates an empty CoW-capable keyed tree with reserved capacity.
        @inlinable
        public init(minimumCapacity: Count) where Element: Copyable {
            _storage = Storage<__TreeKeyedLinks<Key>>(minimumCapacity: minimumCapacity)
        }

        // MARK: - Properties

        /// The number of nodes in the tree (typed — A3).
        @inlinable
        public var count: Count { _storage.count }

        // `isEmpty` / `root` / `validate` / `isLeaf` / `peek` / `clear` / `height` /
        // `parent(of:)` / `remove` / `removeSubtree` are INHERITED from the shared
        // `Tree.Protocol` defaults.

        // MARK: - Arena requirements (delegated to the private Tree.Storage)

        /// The root node's handle (the `Tree.Protocol` arena requirement).
        @inlinable
        public var _rootHandle: Store.Generational.Handle? {
            get { _storage.rootHandle }
            set { _storage.rootHandle = newValue }
        }

        /// Decodes a position to its live handle (the arena requirement).
        @inlinable
        public func _liveHandle(_ position: __TreePosition) -> Store.Generational.Handle? {
            _storage.liveHandle(position)
        }

        /// Inserts a childless node (empty children, no parent key) with the given parent.
        @inlinable
        public mutating func _insertNode(
            _ element: consuming Element,
            parent: Store.Generational.Handle?
        ) -> Store.Generational.Handle {
            _storage.insertNode(element, links: __TreeKeyedLinks<Key>(), parent: parent)
        }

        /// Removes a node, moving its element out (the arena requirement).
        @inlinable
        public mutating func _removeNode(_ handle: Store.Generational.Handle) -> Element {
            _storage.removeNode(handle)
        }

        /// Removes every node and resets the root (the arena requirement).
        @inlinable
        public mutating func _removeAll() { _storage.removeAll() }

        /// The parent handle of a node (the arena requirement).
        @inlinable
        public func _parentHandle(of handle: Store.Generational.Handle) -> Store.Generational.Handle? {
            _storage.parentHandle(of: handle)
        }

        /// Borrowing access to a node's element (the arena requirement).
        @inlinable
        public func _withElement<R: ~Copyable>(
            at handle: Store.Generational.Handle,
            _ body: (borrowing Element) -> R
        ) -> R {
            _storage.withElement(at: handle, body)
        }

        // MARK: - Child-link requirements (key-addressed ordered dictionary)

        /// The child handle under `address` (a key), or `nil` if absent.
        @inlinable
        public func _childHandle(
            at handle: Store.Generational.Handle,
            address: Key
        ) -> Store.Generational.Handle? {
            _storage.withLinks(at: handle) { $0.children.withValue(forKey: address) { $0 } }
        }

        /// Rejects a child link into an occupied key (the per-conformer error precision).
        @inlinable
        public func _validateLink(
            to parent: Store.Generational.Handle,
            at address: Key
        ) throws(__TreeError) {
            let occupied = _storage.withLinks(at: parent) { $0.children.contains(key: address) }
            if occupied { throw .slotOccupied }
        }

        /// Links `child` under `parent` at `address` AND records the back-key on the
        /// child (the both-sides invariant — A1): the ordered-dictionary insert keeps
        /// the parent's child table, and the back-key gives O(1) unlink plus the
        /// `keyPath(to:)` / `key(of:)` source.
        ///
        /// Precondition: a prior `_validateLink` succeeded, so this never fails.
        @inlinable
        public mutating func _linkChild(
            _ child: Store.Generational.Handle,
            to parent: Store.Generational.Handle,
            at address: Key
        ) {
            _storage.withLinksMut(at: parent) { _ = $0.children.insert(key: address, value: child) }
            _storage.withLinksMut(at: child) { $0.parentKey = address }
        }

        /// Unlinks `child` from `parent` — O(1) via the child's back-key (no value scan).
        @inlinable
        public mutating func _unlinkChild(
            _ child: Store.Generational.Handle,
            from parent: Store.Generational.Handle
        ) {
            guard let key = _storage.withLinks(at: child, { $0.parentKey }) else { return }
            _storage.withLinksMut(at: parent) { _ = $0.children.removeValue(forKey: key) }
        }

        /// The number of children of a node.
        @inlinable
        public func _childCount(at handle: Store.Generational.Handle) -> Int {
            Int(bitPattern: _storage.withLinks(at: handle) { $0.children.count })
        }

        /// Visits each child handle in insertion order.
        @inlinable
        public func _forEachChild(
            at handle: Store.Generational.Handle,
            _ body: (Store.Generational.Handle) -> Void
        ) {
            _storage.withLinks(at: handle) { links in
                links.children.forEach { _, child in body(child) }
            }
        }

        // MARK: - Position plumbing (kept)
        //
        // The shared `_position(of:)` default is tree-core-internal, so the keyed
        // package mints positions via its own copy (the same slot + projected
        // generation token). NON-PUBLIC `@inlinable` for the inlinable surface.

        /// Mints the public position for a live handle: the slot plus the slot
        /// generation projected into the position's `UInt32` token.
        @inlinable
        func _position(of handle: Store.Generational.Handle) -> Tree.Position {
            Tree.Position(index: handle.index, token: UInt32(truncatingIfNeeded: handle.generation))
        }

        // MARK: - Internal value / link reads (re-anchored over Tree.Storage; call sites unchanged)

        /// Snapshots a node's children as `(key, handle)` pairs in insertion order.
        @inlinable
        func _children(of handle: Store.Generational.Handle) -> [(key: Key, handle: Store.Generational.Handle)] {
            _storage.withLinks(at: handle) { links in
                var out: [(key: Key, handle: Store.Generational.Handle)] = []
                links.children.forEach { key, child in out.append((key, child)) }
                return out
            }
        }

        /// Looks up the child handle under `key`, or `nil` (the kept `of:key:` spelling).
        @inlinable
        func _childHandle(of handle: Store.Generational.Handle, key: Key) -> Store.Generational.Handle? {
            _childHandle(at: handle, address: key)
        }

        /// The key under which a node is stored in its parent (`nil` for the root).
        @inlinable
        func _parentKey(of handle: Store.Generational.Handle) -> Key? {
            _storage.withLinks(at: handle) { $0.parentKey }
        }
    }
}

// MARK: - Insert (~Copyable; the keyed error-mapping wrapper over the shared insert)

extension Tree.Keyed where Element: ~Copyable {

    /// Inserts a value at the specified position.
    ///
    /// A thin wrapper that delegates orchestration to the shared `Tree.Protocol`
    /// insert and re-maps its `__TreeError` into the richer keyed error, re-attaching
    /// the key for the occupied-child case (§1b).
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
        at position: __TreeKeyedInsertPosition<Key>
    ) throws(__TreeKeyedError<Key>) -> Tree.Position {
        switch position {
        case .root:
            do {
                return try insert(value, at: __TreeInsertPosition<Key>.root)
            } catch {
                throw Self._map(error)
            }
        case .child(of: let parent, let key):
            do {
                return try insert(value, at: __TreeInsertPosition<Key>.child(of: parent, at: key))
            } catch {
                throw Self._map(error, key: key)
            }
        }
    }

    /// Translates a shared `__TreeError` into the richer keyed error, re-attaching
    /// the key for the occupied-child case (§1b). `.slotOccupied` only arises on the
    /// `.child` path, where `key` is present.
    @inlinable
    static func _map(_ error: __TreeError, key: Key? = nil) -> __TreeKeyedError<Key> {
        switch error {
        case .slotOccupied: return key.map { .keyOccupied($0) } ?? .invalidPosition
        case .rootOccupied: return .rootOccupied
        case .invalidPosition: return .invalidPosition
        case .cannotRemoveNonLeaf: return .cannotRemoveNonLeaf
        case .childIndexOutOfBounds: return .invalidPosition
        }
    }
}

// MARK: - Copyable value operations

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
            return _value(of: rootHandle)
        }
        set {
            guard let newValue else { return }
            if let rootHandle = _rootHandle {
                _storage.withElementMut(at: rootHandle) { $0 = newValue }
            } else {
                _rootHandle = _insertNode(newValue, parent: nil)
            }
        }
    }

    /// Inserts a value at the specified position (CoW-aware).
    ///
    /// Uniqueness is restored by the `withUnique` gate inside each storage mutation,
    /// so a tree sharing its column with a copy detaches before writing. Delegates to
    /// the shared insert and maps the error (§1b).
    @inlinable
    @discardableResult
    public mutating func insert(
        _ value: Value,
        at position: __TreeKeyedInsertPosition<Key>
    ) throws(__TreeKeyedError<Key>) -> Tree.Position {
        switch position {
        case .root:
            do {
                return try insert(value, at: __TreeInsertPosition<Key>.root)
            } catch {
                throw Self._map(error)
            }
        case .child(of: let parent, let key):
            do {
                return try insert(value, at: __TreeInsertPosition<Key>.child(of: parent, at: key))
            } catch {
                throw Self._map(error, key: key)
            }
        }
    }

    /// Replaces the value at the specified position.
    ///
    /// - Parameters:
    ///   - position: The position of the node.
    ///   - newValue: The new value.
    /// - Throws: ``Error/invalidPosition`` if the position is invalid or stale.
    @inlinable
    public mutating func update(at position: Tree.Position, _ newValue: Value) throws(__TreeKeyedError<Key>) {
        guard let handle = _liveHandle(position) else { throw .invalidPosition }
        _storage.withElementMut(at: handle) { $0 = newValue }
    }

    /// The value at a live handle (the re-anchored `_node(h){ $0.value }` read).
    @inlinable
    func _value(of handle: Store.Generational.Handle) -> Value {
        _storage.withElement(at: handle) { $0 }
    }
}

// MARK: - Conditional Copyable (CoW; rides the `Tree.Storage` Copyable twin)

extension Tree.Keyed: Copyable where Element: Copyable {}

// MARK: - Sendable
//
// PROPER conditional Sendable (no `@unchecked`, no `@unsafe`): it rides the arena's
// Sendable chain — `Tree.Storage` is `Sendable where Element, ChildLinks: Sendable`;
// `__TreeKeyedLinks<Key>` is `Sendable where Key: Sendable` (the children column's
// `Shared`/dictionary chain carries it; the handle is always `Sendable`).

extension Tree.Keyed: Sendable where Key: Sendable, Element: Sendable {}
