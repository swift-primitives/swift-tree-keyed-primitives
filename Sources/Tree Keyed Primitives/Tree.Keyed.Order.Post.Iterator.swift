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
public import Stack_Primitive
internal import Stack_Primitives
internal import Iterator_Primitive
internal import Iterator_Protocol

extension Tree.Keyed.Order.Post {

    /// An iterator for post-order traversal.
    ///
    /// Uses a two-stack approach: first builds reverse post-order via pre-order,
    /// then yields values in the correct order.
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol` {
        @usableFromInline
        let tree: Tree<Element>.Keyed<Key>

        @usableFromInline
        var output: Stack<Index<Tree<Element>.Keyed<Key>.Node>>

        init(tree: Tree<Element>.Keyed<Key>) {
            self.tree = tree
            self.output = Stack<Index<Tree<Element>.Keyed<Key>.Node>>()

            // Build reverse post-order via pre-order traversal
            var pending = Stack<Index<Tree<Element>.Keyed<Key>.Node>>()
            if let rootIndex = tree._rootIndex {
                pending.push(rootIndex)
            }

            while !pending.isEmpty {
                let index = pending.pop()!
                output.push(index)

                let nodePtr = unsafe tree._arena.pointer(at: index)
                unsafe nodePtr.pointee._children.forEach { _, childIndex in
                    pending.push(childIndex)
                }
            }
        }

        @inlinable
        public mutating func next() -> Element? {
            guard !output.isEmpty else { return nil }
            let index = output.pop()!
            let nodePtr = unsafe tree._arena.pointer(at: index)
            return unsafe nodePtr.pointee.value
        }
    }
}
