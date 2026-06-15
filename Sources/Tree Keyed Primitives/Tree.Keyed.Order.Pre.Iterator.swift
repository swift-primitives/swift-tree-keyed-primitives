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
internal import Stack_Primitives
internal import Iterator_Primitive
internal import Iterator_Protocol

extension Tree.Keyed.Order.Pre {

    /// An iterator for pre-order traversal.
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol` {
        @usableFromInline
        let tree: Tree<Element>.Keyed<Key>

        @usableFromInline
        var pending: Stack<Store.Generational.Handle>

        init(tree: Tree<Element>.Keyed<Key>) {
            self.tree = tree
            self.pending = Stack<Store.Generational.Handle>()
            if let rootHandle = tree._rootHandle {
                self.pending.push(rootHandle)
            }
        }

        @inlinable
        public mutating func next() -> Element? {
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
