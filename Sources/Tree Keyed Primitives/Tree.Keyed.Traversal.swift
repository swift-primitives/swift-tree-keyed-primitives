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

// MARK: - Traversal Sequences (Copyable values only)
//
// The closure-based `forEachPreOrder` / `forEachPostOrder` / `forEachLevelOrder`
// are INHERITED from the shared `Tree.Protocol` defaults (shape-agnostic). This
// file keeps only the `Iterable`/`Sequenceable` traversal VIEWS — the canonical
// collection path (`Array(tree.preOrder)` / `tree.preOrder.reduce(into:)`).

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
