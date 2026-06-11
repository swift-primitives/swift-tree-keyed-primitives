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
internal import Iterator_Primitive
internal import Iterator_Protocol

extension Tree.Keyed.Order.Level {

    /// An iterator for level-order traversal.
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol` {
        @usableFromInline
        let tree: Tree<Element>.Keyed<Key>

        /// The pending-node FIFO on the `Shared` ring column — the CoW flavor is
        /// required here (not the move-only direct ring) so the iterator struct
        /// itself stays `Copyable`, preserving its pre-reshape shape.
        @usableFromInline
        var pending: Queue<Shared<Store.Generational.Handle, Column.Ring<Store.Generational.Handle>>>

        init(tree: Tree<Element>.Keyed<Key>) {
            self.tree = tree
            self.pending = Queue<Shared<Store.Generational.Handle, Column.Ring<Store.Generational.Handle>>>()

            if let rootHandle = tree._rootHandle {
                pending.enqueue(rootHandle)
            }
        }

        @inlinable
        public mutating func next() -> Element? {
            guard !pending.isEmpty else { return nil }

            let handle = pending.dequeue()!
            let value = tree._node(handle) { $0.value }

            for (_, child) in tree._children(of: handle) {
                pending.enqueue(child)
            }

            return value
        }
    }
}
