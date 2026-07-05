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
public import Dictionary_Primitive
public import Hash_Indexed_Primitive
public import Hash_Primitives
public import Index_Primitives
public import Storage_Generational_Primitives
public import Store_Primitive
public import Tree_Primitives

// MARK: - TreeStorage.Keyed — the KEYED storage column
//
// `TreeStorage.Keyed<Element, Key>` is the keyed tree's storage capability conformer
// ([DS-025]/[DS-027]): an ordered key→child-handle map (the ``__TreeKeyedLinks`` child
// links + `parentKey` back-key) over the generational ``__TreeArena``. It is the `S` of
// the canonical keyed tree `__Tree<TreeStorage.Keyed<Element, Key>>` (the
// `Tree<Element>.Keyed<Key>` front door). Mirrors ``TreeStorage/Dynamic`` exactly —
// only the child-link representation
// differs: the dynamic column uses a dense `[Handle]` (addressed by ordinal), the keyed
// column uses the ordered keyed dictionary (addressed by `Key`).

extension TreeStorage {

    /// The keyed (dictionary-indexed) tree storage column.
    ///
    /// Each node has an insertion-ordered set of children indexed by unique keys
    /// (`Address == Key`): O(1) lookup by key, O(1) parent navigation, O(d) key-path
    /// reconstruction. The node payload is `Element`; the per-node keyed children +
    /// `parentKey` back-key live in the ``__TreeKeyedLinks`` `ChildLinks` slot.
    public struct Keyed<Element: ~Copyable, Key: Hash.`Protocol`>: ~Copyable {

        /// Children are addressed by a unique key in this column's child domain.
        public typealias Address = Key

        /// The private generational arena (NON-PUBLIC — `@usableFromInline` for the
        /// inlinable witnesses).
        @usableFromInline
        var _arena: __TreeArena<Element, __TreeKeyedLinks<Key>>

        /// Creates an empty keyed column (move-only elements).
        @inlinable
        public init() { _arena = __TreeArena<Element, __TreeKeyedLinks<Key>>() }

        /// Creates an empty keyed column with reserved capacity (move-only elements).
        @inlinable
        public init(minimumCapacity: Index<Element>.Count) {
            _arena = __TreeArena<Element, __TreeKeyedLinks<Key>>(minimumCapacity: minimumCapacity)
        }

        /// Creates an empty CoW-capable keyed column (the clone strategy is captured here).
        @inlinable
        public init() where Element: Copyable {
            _arena = __TreeArena<Element, __TreeKeyedLinks<Key>>()
        }

        /// Creates an empty CoW-capable keyed column with reserved capacity.
        @inlinable
        public init(minimumCapacity: Index<Element>.Count) where Element: Copyable {
            _arena = __TreeArena<Element, __TreeKeyedLinks<Key>>(minimumCapacity: minimumCapacity)
        }
    }
}

// MARK: - __TreeStorage conformance (the arena + keyed child-link witnesses)

extension TreeStorage.Keyed: __TreeStorage {

    // MARK: Arena requirements (delegated to the private __TreeArena)

    /// The number of live nodes (typed — A3).
    @inlinable
    public var _count: Index<Element>.Count { _arena.count }

    /// The root node's handle.
    @inlinable
    public var _rootHandle: Store.Generational.Handle? {
        get { _arena.rootHandle }
        set { _arena.rootHandle = newValue }
    }

    /// Decodes a position to its live handle.
    @inlinable
    public func _liveHandle(_ position: __TreePosition) -> Store.Generational.Handle? {
        _arena.liveHandle(position)
    }

    /// Inserts a childless node (empty keyed children, no parent key) with the given parent.
    @inlinable
    public mutating func _insertNode(
        _ element: consuming Element,
        parent: Store.Generational.Handle?
    ) -> Store.Generational.Handle {
        _arena.insertNode(element, links: __TreeKeyedLinks<Key>(), parent: parent)
    }

    /// Removes a node, moving its element out.
    @inlinable
    public mutating func _removeNode(_ handle: Store.Generational.Handle) -> Element {
        _arena.removeNode(handle)
    }

    /// Removes every node and resets the root.
    @inlinable
    public mutating func _removeAll() { _arena.removeAll() }

    /// The parent handle of a node.
    @inlinable
    public func _parentHandle(of handle: Store.Generational.Handle) -> Store.Generational.Handle? {
        _arena.parentHandle(of: handle)
    }

    /// Borrowing access to a node's element.
    @inlinable
    public func _withElement<R: ~Copyable>(
        at handle: Store.Generational.Handle,
        _ body: (borrowing Element) -> R
    ) -> R {
        _arena.withElement(at: handle, body)
    }

    /// In-place (position-stable) mutating access to a node's element.
    @inlinable
    public mutating func _withElementMut<R: ~Copyable>(
        at handle: Store.Generational.Handle,
        _ body: (inout Element) -> R
    ) -> R {
        _arena.withElementMut(at: handle, body)
    }

    // MARK: Child-link requirements (key-addressed ordered dictionary)

    /// The child handle under `address` (a key), or `nil` if absent.
    @inlinable
    public func _childHandle(
        at handle: Store.Generational.Handle,
        address: Key
    ) -> Store.Generational.Handle? {
        _arena.withLinks(at: handle) { $0.children.withValue(forKey: address) { $0 } }
    }

    /// Rejects a child link into an occupied key (the per-column error precision).
    @inlinable
    public func _validateLink(
        to parent: Store.Generational.Handle,
        at address: Key
    ) throws(__TreeError) {
        let occupied = _arena.withLinks(at: parent) { $0.children.contains(key: address) }
        if occupied { throw .slotOccupied }
    }

    /// Links `child` under `parent` at `address` AND records the back-key on the child
    /// (the both-sides invariant — A1): the ordered-dictionary insert keeps the parent's
    /// child table, and the back-key gives O(1) unlink plus the `keyPath` / `key` source.
    @inlinable
    public mutating func _linkChild(
        _ child: Store.Generational.Handle,
        to parent: Store.Generational.Handle,
        at address: Key
    ) {
        _arena.withLinksMut(at: parent) { _ = $0.children.insert(key: address, value: child) }
        _arena.withLinksMut(at: child) { $0.parentKey = address }
    }

    /// Unlinks `child` from `parent` — O(1) via the child's back-key (no value scan).
    @inlinable
    public mutating func _unlinkChild(
        _ child: Store.Generational.Handle,
        from parent: Store.Generational.Handle
    ) {
        guard let key = _arena.withLinks(at: child, { $0.parentKey }) else { return }
        _arena.withLinksMut(at: parent) { _ = $0.children.removeValue(forKey: key) }
    }

    /// The number of children of a node.
    @inlinable
    public func _childCount(at handle: Store.Generational.Handle) -> Int {
        Int(bitPattern: _arena.withLinks(at: handle) { $0.children.count })
    }

    /// Visits each child handle in insertion order.
    @inlinable
    public func _forEachChild(
        at handle: Store.Generational.Handle,
        _ body: (Store.Generational.Handle) -> Void
    ) {
        _arena.withLinks(at: handle) { links in
            links.children.forEach { _, child in body(child) }
        }
    }
}

// MARK: - __TreeKeyedStorage conformance (the reverse-key reads)

extension TreeStorage.Keyed: __TreeKeyedStorage {

    /// The key under which a node is stored in its parent (`nil` for the root).
    @inlinable
    public func _parentKey(of handle: Store.Generational.Handle) -> Key? {
        _arena.withLinks(at: handle) { $0.parentKey }
    }

    /// Snapshots a node's children as `(key, handle)` pairs in insertion order.
    @inlinable
    public func _children(
        of handle: Store.Generational.Handle
    ) -> [(key: Key, handle: Store.Generational.Handle)] {
        _arena.withLinks(at: handle) { links in
            var out: [(key: Key, handle: Store.Generational.Handle)] = []
            links.children.forEach { key, child in out.append((key, child)) }
            return out
        }
    }
}

// MARK: - Copyable / Sendable (flow from the element; the keyed links are always Copyable)

extension TreeStorage.Keyed: Copyable where Element: Copyable {}

extension TreeStorage.Keyed: Sendable where Element: Sendable, Key: Sendable {}

// MARK: - Column-pinned construction (the `TreeStorage.Dynamic` mechanic: method-level `where ==`)

extension __Tree where S: ~Copyable {

    /// Creates an empty keyed tree (move-only values).
    @inlinable
    public init<Element: ~Copyable, Key: Hash.`Protocol`>()
    where S == TreeStorage.Keyed<Element, Key> {
        self.init(storage: TreeStorage.Keyed<Element, Key>())
    }

    /// Creates an empty keyed tree with reserved capacity (move-only values).
    @inlinable
    public init<Element: ~Copyable, Key: Hash.`Protocol`>(
        minimumCapacity: Index_Primitives.Index<Element>.Count
    ) where S == TreeStorage.Keyed<Element, Key> {
        self.init(storage: TreeStorage.Keyed<Element, Key>(minimumCapacity: minimumCapacity))
    }

    /// Creates an empty CoW-capable keyed tree (captures the clone strategy).
    @inlinable
    public init<Element, Key: Hash.`Protocol`>()
    where S == TreeStorage.Keyed<Element, Key> {
        self.init(storage: TreeStorage.Keyed<Element, Key>())
    }

    /// Creates an empty CoW-capable keyed tree with reserved capacity.
    @inlinable
    public init<Element, Key: Hash.`Protocol`>(
        minimumCapacity: Index_Primitives.Index<Element>.Count
    ) where S == TreeStorage.Keyed<Element, Key> {
        self.init(storage: TreeStorage.Keyed<Element, Key>(minimumCapacity: minimumCapacity))
    }

    /// Creates a CoW-capable keyed tree with a single root node.
    @inlinable
    public init<Element, Key: Hash.`Protocol`>(rootValue: consuming Element)
    where S == TreeStorage.Keyed<Element, Key> {
        self.init(storage: TreeStorage.Keyed<Element, Key>())
        let handle = _storage._insertNode(rootValue, parent: nil)
        _storage._rootHandle = handle
    }
}

// The former `TreeKeyed` compound ergonomic alias is RETIRED (the §9.6.5 [API-NAME-001]
// hygiene class, alongside `TreeDynamic`): the canonical spelling is the
// `Tree<Element>.Keyed<Key>` front door (`Tree.Keyed.FrontDoor.swift`, this target).
// The 6.3.2 frontend crash that forced the compound top-level alias is fixed on 6.3.3.
