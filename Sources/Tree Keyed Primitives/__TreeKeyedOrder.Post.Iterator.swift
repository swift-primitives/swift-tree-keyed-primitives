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

internal import Iterator_Primitive
internal import Iterator_Protocol
public import Stack_Primitive
internal import Stack_Primitives
public import Storage_Generational_Primitives
public import Store_Primitive
public import Tree_Primitives

extension __TreeKeyedOrder.Post {

    /// An iterator for post-order traversal (children in insertion order, then root).
    ///
    /// Uses a two-stack approach: first builds reverse post-order via pre-order,
    /// then yields values in the correct order.
    ///
    /// Move-only (`~Copyable`): the traversal scratch is the canonical direct
    /// `Stack<Handle>`, which is move-only regardless of element (the W2 stack reshape);
    /// the whole `Iterator.Protocol` / `Iterable` / `Materializing` machinery suppresses
    /// `~Copyable`, so the iterator rides it without a CoW column (seat D3 ruling (a)).
    public struct Iterator<S: __TreeKeyedStorage>: ~Copyable, Iterator_Primitive.Iterator.`Protocol`
    where S.Element: Copyable {
        @usableFromInline
        let tree: __Tree<S>

        @usableFromInline
        var output: Stack<Store.Generational.Handle>

        @usableFromInline
        init(tree: __Tree<S>) {
            self.tree = tree
            self.output = Stack<Store.Generational.Handle>()

            // Build reverse post-order via pre-order traversal
            var pending = Stack<Store.Generational.Handle>()
            if let rootHandle = tree._rootHandle {
                pending.push(rootHandle)
            }

            while let handle = pending.pop() {
                output.push(handle)

                for (_, child) in tree._children(of: handle) {
                    pending.push(child)
                }
            }
        }

        /// Advances to the next node in post-order (children before parent), or
        /// returns `nil` when traversal is exhausted.
        @inlinable
        public mutating func next() -> S.Element? {
            guard let handle = output.pop() else { return nil }
            return tree._value(of: handle)
        }
    }
}
