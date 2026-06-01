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
public import Stack_Primitive
internal import Stack_Primitives
internal import Iterator_Primitive
internal import Iterator_Protocol

extension Tree.Keyed.Order.Pre {

    /// An iterator for pre-order traversal.
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol` {
        @usableFromInline
        let tree: Tree<Element>.Keyed<Key>

        @usableFromInline
        var pending: Stack<Index<Tree<Element>.Keyed<Key>.Node>>

        init(tree: Tree<Element>.Keyed<Key>) {
            self.tree = tree
            self.pending = Stack<Index<Tree<Element>.Keyed<Key>.Node>>()
            if let rootIndex = tree._rootIndex {
                self.pending.push(rootIndex)
            }
        }

        @inlinable
        public mutating func next() -> Element? {
            guard !pending.isEmpty else { return nil }

            let index = pending.pop()!
            let nodePtr = unsafe tree._arena.pointer(at: index)
            let value = unsafe nodePtr.pointee.value

            // Collect children, push in reverse for correct order
            var childIndices: [Index<Tree<Element>.Keyed<Key>.Node>] = []
            unsafe nodePtr.pointee._children.forEach { _, childIndex in
                childIndices.append(childIndex)
            }
            for i in (0..<childIndices.count).reversed() {
                pending.push(childIndices[i])
            }

            return value
        }
    }
}
