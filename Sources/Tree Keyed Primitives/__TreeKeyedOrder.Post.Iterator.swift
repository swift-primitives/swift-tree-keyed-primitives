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
public import Stack_Primitive
public import Tree_Primitives
internal import Stack_Primitives
internal import Iterator_Primitive
internal import Iterator_Protocol

extension __TreeKeyedOrder.Post {

    /// An iterator for post-order traversal (children in insertion order, then root).
    ///
    /// Uses a two-stack approach: first builds reverse post-order via pre-order,
    /// then yields values in the correct order.
    public struct Iterator<S: __TreeKeyedStorage>: Iterator_Primitive.Iterator.`Protocol`
    where S.Element: Copyable {
        @usableFromInline
        let tree: Tree<S>

        @usableFromInline
        var output: Stack<Store.Generational.Handle>

        @usableFromInline
        init(tree: Tree<S>) {
            self.tree = tree
            self.output = Stack<Store.Generational.Handle>()

            // Build reverse post-order via pre-order traversal
            var pending = Stack<Store.Generational.Handle>()
            if let rootHandle = tree._rootHandle {
                pending.push(rootHandle)
            }

            while !pending.isEmpty {
                let handle = pending.pop()!
                output.push(handle)

                for (_, child) in tree._children(of: handle) {
                    pending.push(child)
                }
            }
        }

        @inlinable
        public mutating func next() -> S.Element? {
            guard !output.isEmpty else { return nil }
            let handle = output.pop()!
            return tree._value(of: handle)
        }
    }
}
