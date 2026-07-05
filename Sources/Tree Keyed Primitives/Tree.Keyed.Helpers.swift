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

public import Store_Primitive
public import Storage_Generational_Primitives
public import Tree_Primitives

// MARK: - Keyed tree vocabulary + handle-level seams (the de-compounded port surface)
//
// The keyed-specific surface ([DS-027]) lives on the carrier constrained to the keyed
// column capability (`extension __Tree where S: __TreeKeyedStorage`). The shared insert /
// remove / navigation / traversal come from the tree-core `Tree+Operations` engine for
// free; these handle-level helpers re-anchor the keyed algorithms' internal reads onto
// the column through the public `__Tree<S>._storage` seam, so the salvaged algorithm
// bodies carry forward with only their extension header changed. `_position(of:)` /
// `_liveHandle(_:)` are inherited from `Tree+Operations` and are NOT redefined here.

extension __Tree where S: __TreeKeyedStorage {

    /// The value stored at each node (the keyed tree's element).
    public typealias Value = S.Element

    /// How a child is addressed within its parent: a unique key.
    public typealias Key = S.Address

    /// The root node's handle, or `nil` if the tree is empty.
    @usableFromInline
    var _rootHandle: Store.Generational.Handle? {
        @inlinable get { _storage._rootHandle }
        @inlinable set { _storage._rootHandle = newValue }
    }

    /// The parent handle of a node (`nil` for the root).
    @inlinable
    func _parentHandle(of handle: Store.Generational.Handle) -> Store.Generational.Handle? {
        _storage._parentHandle(of: handle)
    }

    /// The key under which a node is stored in its parent (`nil` for the root).
    @inlinable
    func _parentKey(of handle: Store.Generational.Handle) -> Key? {
        _storage._parentKey(of: handle)
    }

    /// A node's children as ordered `(key, handle)` pairs, in insertion order.
    @inlinable
    func _children(
        of handle: Store.Generational.Handle
    ) -> [(key: Key, handle: Store.Generational.Handle)] {
        _storage._children(of: handle)
    }

    /// The child handle under `key`, or `nil` if absent.
    @inlinable
    func _childHandle(
        of handle: Store.Generational.Handle,
        key: Key
    ) -> Store.Generational.Handle? {
        _storage._childHandle(at: handle, address: key)
    }

    /// Inserts a childless node with the given parent; returns its handle.
    @inlinable
    mutating func _insertNode(
        _ value: consuming Value,
        parent: Store.Generational.Handle?
    ) -> Store.Generational.Handle {
        _storage._insertNode(value, parent: parent)
    }

    /// Links `child` under `parent` at `key` (precondition: `key` is free).
    @inlinable
    mutating func _linkChild(
        _ child: Store.Generational.Handle,
        to parent: Store.Generational.Handle,
        at key: Key
    ) {
        _storage._linkChild(child, to: parent, at: key)
    }
}

// MARK: - Copyable-value handle seams

extension __Tree where S: __TreeKeyedStorage, S.Element: Copyable {

    /// The value at a live handle.
    @inlinable
    func _value(of handle: Store.Generational.Handle) -> Value {
        _storage._withElement(at: handle) { $0 }
    }

    /// Replaces the value at a live handle in place (position-stable).
    @inlinable
    mutating func _setValue(at handle: Store.Generational.Handle, _ value: Value) {
        _storage._withElementMut(at: handle) { $0 = value }
    }
}
