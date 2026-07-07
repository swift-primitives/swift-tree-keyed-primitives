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

public import Buffer_Ring_Primitive
public import Column_Primitives
internal import Iterator_Primitive
internal import Iterator_Protocol
public import Ownership_Shared_Primitive
public import Queue_Primitives
public import Storage_Generational_Primitives
public import Store_Primitive
public import Tree_Primitives

extension __TreeKeyedOrder.Level {

    /// An iterator for level-order (breadth-first) traversal.
    public struct Iterator<S: __TreeKeyedStorage>: Iterator_Primitive.Iterator.`Protocol`
    where S.Element: Copyable {
        @usableFromInline
        let tree: __Tree<S>

        /// The pending-node FIFO on the `Shared` ring column — the CoW flavor keeps the
        /// iterator struct itself `Copyable`.
        @usableFromInline
        var pending: __Queue<Ownership.Shared<Store.Generational.Handle, Column.Ring<Store.Generational.Handle>>>

        @usableFromInline
        init(tree: __Tree<S>) {
            self.tree = tree
            self.pending = __Queue<Ownership.Shared<Store.Generational.Handle, Column.Ring<Store.Generational.Handle>>>()

            if let rootHandle = tree._rootHandle {
                pending.enqueue(rootHandle)
            }
        }

        /// Advances to the next node in level-order (breadth-first, children in
        /// insertion order), or returns `nil` when traversal is exhausted.
        @inlinable
        public mutating func next() -> S.Element? {
            guard let handle = pending.dequeue() else { return nil }

            let value = tree._value(of: handle)

            for (_, child) in tree._children(of: handle) {
                pending.enqueue(child)
            }

            return value
        }
    }
}
