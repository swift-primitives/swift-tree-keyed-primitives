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

public import Buffer_Arena_Primitive
public import Dictionary_Ordered_Primitives
public import Queue_Primitives
internal import Iterator_Primitive
internal import Iterator_Protocol

extension Tree.Keyed.Order.Level {

    /// An iterator for level-order traversal.
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol` {
        @usableFromInline
        let tree: Tree<Element>.Keyed<Key>

        @usableFromInline
        var pending: Queue<Index<Tree<Element>.Keyed<Key>.Node>>

        init(tree: Tree<Element>.Keyed<Key>) {
            self.tree = tree
            self.pending = Queue<Index<Tree<Element>.Keyed<Key>.Node>>()

            if let rootIndex = tree._rootIndex {
                pending.enqueue(rootIndex)
            }
        }

        @inlinable
        public mutating func next() -> Element? {
            guard !pending.isEmpty else { return nil }

            let index = pending.dequeue()!
            let value = tree._arena[index].value

            tree._arena[index]._children.forEach { _, childIndex in
                pending.enqueue(childIndex)
            }

            return value
        }
    }
}
