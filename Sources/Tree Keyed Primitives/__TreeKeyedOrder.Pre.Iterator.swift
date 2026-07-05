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

extension __TreeKeyedOrder.Pre {

    /// An iterator for pre-order traversal (root, then children in insertion order).
    ///
    /// Move-only (`~Copyable`): the traversal scratch is the canonical direct
    /// `Stack<Handle>`, which is move-only regardless of element (the W2 stack reshape);
    /// the whole `Iterator.Protocol` / `Iterable` / `Materializing` machinery suppresses
    /// `~Copyable`, so the iterator rides it without a CoW column (seat D3 ruling (a) —
    /// no `Stack` `Shared` push twin is shipped, so the CoW-scratch shape (c′) is
    /// unavailable).
    public struct Iterator<S: __TreeKeyedStorage>: ~Copyable, Iterator_Primitive.Iterator.`Protocol`
    where S.Element: Copyable {
        @usableFromInline
        let tree: __Tree<S>

        @usableFromInline
        var pending: Stack<Store.Generational.Handle>

        @usableFromInline
        init(tree: __Tree<S>) {
            self.tree = tree
            self.pending = Stack<Store.Generational.Handle>()
            if let rootHandle = tree._rootHandle {
                self.pending.push(rootHandle)
            }
        }

        @inlinable
        public mutating func next() -> S.Element? {
            guard !pending.isEmpty else { return nil }

            let handle = pending.pop()!
            let value = tree._value(of: handle)

            // Collect children, push in reverse for correct order
            let children = tree._children(of: handle)
            for i in (0..<children.count).reversed() {
                pending.push(children[i].handle)
            }

            return value
        }
    }
}
