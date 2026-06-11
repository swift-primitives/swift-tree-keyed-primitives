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
public import Shared_Primitive
public import Dictionary_Ordered_Primitives

// MARK: - Navigation

extension Tree.Keyed where Element: ~Copyable {

    /// Returns the position of the child with the given key.
    ///
    /// - Parameters:
    ///   - position: The position of the parent node.
    ///   - key: The child key to look up.
    /// - Returns: The position of the child, or `nil` if the key is not found.
    /// - Note: Returns `nil` if the position is invalid (stale or out of bounds).
    @inlinable
    public func child(of position: Tree.Position, key: Key) -> Tree.Position? {
        guard let handle = try? _handle(position) else { return nil }
        guard let childHandle = _childHandle(of: handle, key: key) else { return nil }
        return _position(of: childHandle)
    }

    /// Returns the position of the parent of the node at the given position.
    ///
    /// - Parameter position: The position of the child node.
    /// - Returns: The position of the parent, or `nil` if the node is the root.
    /// - Note: Returns `nil` if the position is invalid (stale or out of bounds).
    @inlinable
    public func parent(of position: Tree.Position) -> Tree.Position? {
        guard let handle = try? _handle(position) else { return nil }
        guard let parentHandle = _node(handle, { $0.parentHandle }) else {
            return nil
        }
        return _position(of: parentHandle)
    }

    /// Returns the key under which this node is stored in its parent.
    ///
    /// - Parameter position: The position of the node.
    /// - Returns: The parent key, or `nil` if the node is the root or position is invalid.
    @inlinable
    public func key(of position: Tree.Position) -> Key? {
        guard let handle = try? _handle(position) else { return nil }
        return _node(handle) { $0.parentKey }
    }

    /// Returns whether the node at the given position is a leaf (has no children).
    ///
    /// - Parameter position: The position to check.
    /// - Returns: `true` if the node has no children, `false` otherwise.
    /// - Note: Returns `false` if the position is invalid (stale or out of bounds).
    @inlinable
    public func isLeaf(_ position: Tree.Position) -> Bool {
        guard let handle = try? _handle(position) else { return false }
        return _node(handle) { $0._children.isEmpty }
    }

    /// Returns the number of children of the node at the given position.
    ///
    /// - Parameter position: The position to check.
    /// - Returns: The number of children, or `nil` if position is invalid.
    @inlinable
    public func childCount(of position: Tree.Position) -> Count? {
        guard let handle = try? _handle(position) else { return nil }
        return _node(handle) { $0._children.count.retag(Node.self) }
    }

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
    public func children(of position: Tree.Position) -> [(key: Key, position: Tree.Position)]? {
        guard let handle = try? _handle(position) else { return nil }
        var result: [(key: Key, position: Tree.Position)] = []
        for (key, childHandle) in _children(of: handle) {
            result.append((key, _position(of: childHandle)))
        }
        return result
    }

    /// Calls the given closure for each child of the node at the given position.
    ///
    /// Children are visited in insertion order.
    ///
    /// - Parameters:
    ///   - position: The position of the parent node.
    ///   - body: A closure called with each child's key and position.
    @inlinable
    public func forEachChild(
        of position: Tree.Position,
        _ body: (Key, Tree.Position) -> Void
    ) {
        guard let handle = try? _handle(position) else { return }
        for (key, childHandle) in _children(of: handle) {
            body(key, _position(of: childHandle))
        }
    }
}
