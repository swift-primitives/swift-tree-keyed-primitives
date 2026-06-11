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
public import Column_Primitives
public import Buffer_Ring_Primitive
public import Queue_Primitives
public import Stack_Primitive

// MARK: - Traversal (~Copyable)

extension Tree.Keyed where Element: ~Copyable {

    /// Iterates over all values in pre-order using a borrowing closure.
    ///
    /// Uses iterative traversal to avoid stack overflow on deep trees.
    /// Children are visited in insertion order.
    ///
    /// - Parameter body: A closure called with each value in pre-order.
    @inlinable
    public func forEachPreOrder(_ body: (borrowing Value) -> Void) {
        guard let rootHandle = _rootHandle else { return }
        var pending = Stack<Store.Generational.Handle>()
        pending.push(rootHandle)

        while !pending.isEmpty {
            let handle = pending.pop()!
            _storage.withColumn { body($0[handle].value) }

            // Collect children, then push in reverse for correct order
            let children = _children(of: handle)
            for i in (0..<children.count).reversed() {
                pending.push(children[i].handle)
            }
        }
    }

    /// Iterates over all values in post-order using a borrowing closure.
    ///
    /// Uses iterative traversal to avoid stack overflow on deep trees.
    /// Children are visited in insertion order.
    ///
    /// - Parameter body: A closure called with each value in post-order.
    @inlinable
    public func forEachPostOrder(_ body: (borrowing Value) -> Void) {
        guard let rootHandle = _rootHandle else { return }

        // Two-stack approach: build reverse post-order, then process
        var pending = Stack<Store.Generational.Handle>()
        var output = Stack<Store.Generational.Handle>()

        pending.push(rootHandle)

        while !pending.isEmpty {
            let handle = pending.pop()!
            output.push(handle)

            // Push children in insertion order (leftmost first) so rightmost ends up on top
            for (_, child) in _children(of: handle) {
                pending.push(child)
            }
        }

        // Process in reverse order (post-order)
        while !output.isEmpty {
            let handle = output.pop()!
            _storage.withColumn { body($0[handle].value) }
        }
    }

    /// Iterates over all values in level-order (breadth-first) using a borrowing closure.
    ///
    /// Children are visited in insertion order within each level.
    ///
    /// - Parameter body: A closure called with each value in level-order.
    @inlinable
    public func forEachLevelOrder(_ body: (borrowing Value) -> Void) {
        guard let rootHandle = _rootHandle else { return }

        var pending = Queue<Column.Ring<Store.Generational.Handle>>()
        pending.enqueue(rootHandle)

        while !pending.isEmpty {
            let handle = pending.dequeue()!

            _storage.withColumn { body($0[handle].value) }

            for (_, child) in _children(of: handle) {
                pending.enqueue(child)
            }
        }
    }
}

// MARK: - Traversal Sequences (Copyable values only)

extension Tree.Keyed where Element: Copyable {

    /// A sequence that yields values in pre-order (root, then children in insertion order).
    public var preOrder: Order.Pre.Sequence {
        Order.Pre.Sequence(tree: self)
    }

    /// A sequence that yields values in post-order (children in insertion order, then root).
    public var postOrder: Order.Post.Sequence {
        Order.Post.Sequence(tree: self)
    }

    /// A sequence that yields values in level-order (breadth-first).
    public var levelOrder: Order.Level.Sequence {
        Order.Level.Sequence(tree: self)
    }
}
