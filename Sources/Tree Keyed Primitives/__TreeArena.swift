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
public import Index_Primitives
public import Ownership_Shared_Primitive
public import Storage_Generational_Primitives
public import Store_Primitive
public import Tree_Index_Primitives

// MARK: - __TreeArena — the keyed column's generational arena nucleus
//
// A verbatim local copy of the tree-core `__TreeArena` ([DS-025]): that type is
// `@usableFromInline` INTERNAL to swift-tree-primitives (designed for in-package
// columns), so the keyed column — in a SEPARATE package — cannot wrap the shared one
// and instead carries its own, composed from the same public generational-column
// primitives (`Ownership.Shared<Slot, Column.Generational<Slot>>`). It carries Round M's tree
// work verbatim: B2 `handle(at:)` decode + token validation; A3 typed counts; the
// generation-preserving `grow(to:)` contract; the `Shared` CoW column.
//
// `@usableFromInline`-internal: never crosses the public surface (the column's public
// witnesses traffic in `Element` / `ChildLinks` / `Handle` / `__TreePosition`).

@usableFromInline
struct __TreeArena<Element: ~Copyable, ChildLinks>: ~Copyable {

    @usableFromInline
    typealias Slot = __TreeNode<Element, ChildLinks>

    /// The generational node column behind the `Shared` CoW box.
    @usableFromInline
    var _column: Ownership.Shared<Slot, Column.Generational<Slot>>

    /// The handle of the tree's root node, or `nil` if the tree is empty.
    @usableFromInline
    var rootHandle: Store.Generational.Handle?

    // MARK: Construction twins (MEMBER-LEVEL — the Copyable split mangle-collides at
    // extension level on a generic-over-Element type).

    /// Creates an empty arena (move-only elements — no clone strategy).
    @inlinable
    package init() {
        self._column = Ownership.Shared(Column.Generational<Slot>.create(slotCapacity: 1))
        self.rootHandle = nil
    }

    /// Creates an empty CoW-capable arena.
    @inlinable
    package init() where Element: Copyable, ChildLinks: Copyable {
        self._column = Ownership.Shared(Column.Generational<Slot>.create(slotCapacity: 1))
        self.rootHandle = nil
    }

    /// Creates an empty arena with reserved capacity (move-only elements).
    @inlinable
    package init(minimumCapacity: Index<Element>.Count) {
        let slots = Index<Slot>.Count(UInt(Swift.max(Int(bitPattern: minimumCapacity), 1)))
        self._column = Ownership.Shared(Column.Generational<Slot>.create(slotCapacity: slots))
        self.rootHandle = nil
    }

    /// Creates an empty CoW-capable arena with reserved capacity.
    @inlinable
    package init(minimumCapacity: Index<Element>.Count) where Element: Copyable, ChildLinks: Copyable {
        let slots = Index<Slot>.Count(UInt(Swift.max(Int(bitPattern: minimumCapacity), 1)))
        self._column = Ownership.Shared(Column.Generational<Slot>.create(slotCapacity: slots))
        self.rootHandle = nil
    }

    // MARK: Arena operations

    /// The number of live nodes (typed — A3; tagged by `Element`, one per node).
    @inlinable
    package var count: Index<Element>.Count {
        Index<Element>.Count(UInt(Int(bitPattern: _column.withColumn { $0.count })))
    }

    /// Decodes a position into its live handle, or `nil` if stale or out of bounds.
    @inlinable
    package func liveHandle(_ position: __TreePosition) -> Store.Generational.Handle? {
        let slot = Int(bitPattern: position.index)
        guard
            slot >= 0,
            let handle = _column.withColumn({ $0.handle(at: Index<Slot>(Ordinal(UInt(slot)))) }),
            UInt32(truncatingIfNeeded: handle.generation) == position.token
        else { return nil }
        return handle
    }

    /// Inserts a node (element + links), growing the column first when full.
    @inlinable
    package mutating func insertNode(
        _ element: consuming Element,
        links: consuming ChildLinks,
        parent: Store.Generational.Handle?
    ) -> Store.Generational.Handle {
        _column.withUnique(
            consuming: Slot(element: element, links: links, parentHandle: parent)
        ) { column, node -> Store.Generational.Handle in
            if column.count == column.capacity {
                let doubled = Index<Slot>.Count(UInt(2 &* Int(bitPattern: column.capacity)))
                column.grow(to: doubled)
            }
            return column.insert(node)
        }
    }

    /// Removes the node at a live handle and moves its element out.
    @inlinable
    package mutating func removeNode(_ handle: Store.Generational.Handle) -> Element {
        guard let node = _column.withUnique({ $0.remove(handle) }) else {
            preconditionFailure("__TreeArena: live handle failed to resolve on removal")
        }
        return node.element
    }

    /// Removes every node and resets the root (the `Shared` drain).
    @inlinable
    package mutating func removeAll() {
        _column.withUnique { $0.removeAll() }
        rootHandle = nil
    }

    /// The parent handle of a node (`nil` for the root).
    @inlinable
    package func parentHandle(of handle: Store.Generational.Handle) -> Store.Generational.Handle? {
        _column.withColumn { $0[handle].parentHandle }
    }

    /// Borrowing access to a node's element.
    @inlinable
    package func withElement<R: ~Copyable>(
        at handle: Store.Generational.Handle,
        _ body: (borrowing Element) -> R
    ) -> R {
        _column.withColumn { body($0[handle].element) }
    }

    /// Borrowing access to a node's child links.
    @inlinable
    package func withLinks<R: ~Copyable>(
        at handle: Store.Generational.Handle,
        _ body: (borrowing ChildLinks) -> R
    ) -> R {
        _column.withColumn { body($0[handle].links) }
    }

    /// CoW-gated mutable access to a node's child links.
    @inlinable
    package mutating func withLinksMut<R: ~Copyable>(
        at handle: Store.Generational.Handle,
        _ body: (inout ChildLinks) -> R
    ) -> R {
        _column.withUnique { body(&$0[handle].links) }
    }

    /// CoW-gated mutable access to a node's element (position-stable).
    @inlinable
    package mutating func withElementMut<R: ~Copyable>(
        at handle: Store.Generational.Handle,
        _ body: (inout Element) -> R
    ) -> R {
        _column.withUnique { body(&$0[handle].element) }
    }
}

// MARK: - Copyable (the arena is CoW-capable exactly when its element + links are)

extension __TreeArena: Copyable where Element: Copyable, ChildLinks: Copyable {}

// MARK: - Sendable

extension __TreeArena: Sendable where Element: Sendable, ChildLinks: Sendable {}
