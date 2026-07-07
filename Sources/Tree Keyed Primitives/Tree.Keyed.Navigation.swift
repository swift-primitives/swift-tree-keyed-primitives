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

// MARK: - Navigation

extension __Tree where S: __TreeKeyedStorage {

    // Child-by-key navigation is the shared `tree.child.at(key, of:)` view member
    // (R1 W4 [API-NAME-002]; tree-core `__TreeChild.swift`) — `Address == Key`, so the
    // shared `child.at(_:of:)` does the keyed lookup; the legacy `child(of:key:)` folded in.

    /// Returns the key under which this node is stored in its parent.
    ///
    /// - Parameter position: The position of the node.
    /// - Returns: The parent key, or `nil` if the node is the root or position is invalid.
    @inlinable
    public func key(of position: Position) -> Key? {
        guard let handle = _liveHandle(position) else { return nil }
        return _parentKey(of: handle)
    }

    // The per-node child count is the shared `tree.child.count(of:)` view member
    // (R1 W4 [API-NAME-002]; tree-core `__TreeChild.swift`) — `Int?`, matching the
    // keyed child tally; the compound `childCount(of:)` was folded into `child`.

    /// Returns the keys and positions of all children of the node at the given position.
    ///
    /// Returns a snapshot array that is safe to iterate while mutating the tree.
    /// Positions remain valid across copy-on-write mutations because the `Shared`
    /// column's clone strategy is the GENERATION-PRESERVING deep copy — slot
    /// indices, occupancy, and generations are preserved verbatim.
    ///
    /// - Parameter position: The position of the parent node.
    /// - Returns: An array of (key, position) pairs in insertion order, or nil if position is invalid.
    @inlinable
    public func children(of position: Position) -> [(key: Key, position: Position)]? {
        guard let handle = _liveHandle(position) else { return nil }
        var result: [(key: Key, position: Position)] = []
        for (key, childHandle) in _children(of: handle) {
            result.append((key, _position(of: childHandle)))
        }
        return result
    }

    /// Calls the given closure for each child of the node at the given position,
    /// in insertion order, passing each child's key and position.
    ///
    /// (Closure overload of ``children(of:)`` — R1 W4 [API-NAME-002] de-compounding
    /// of `forEachChild`.)
    ///
    /// - Parameters:
    ///   - position: The position of the parent node.
    ///   - body: A closure called with each child's key and position.
    @inlinable
    public func children(
        of position: Position,
        _ body: (Key, Position) -> Void
    ) {
        guard let handle = _liveHandle(position) else { return }
        for (key, childHandle) in _children(of: handle) {
            body(key, _position(of: childHandle))
        }
    }
}
