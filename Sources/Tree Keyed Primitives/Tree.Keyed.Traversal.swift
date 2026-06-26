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

public import Tree_Primitives

// MARK: - Traversal Sequences (Copyable values only)
//
// The closure-based `forEach.preOrder { }` / `.postOrder { }` / `.levelOrder { }` are
// INHERITED from the shared tree-core engine (shape-agnostic). These properties surface
// the `Iterable`/`Sequenceable` traversal VIEWS — the canonical collection path
// (`Array(tree.preOrder)` / `tree.preOrder.reduce(into:)`).

extension Tree where S: __TreeKeyedStorage, S.Element: Copyable {

    /// A sequence that yields values in pre-order (root, then children in insertion order).
    public var preOrder: __TreeKeyedOrder.Pre.Sequence<S> {
        __TreeKeyedOrder.Pre.Sequence<S>(tree: self)
    }

    /// A sequence that yields values in post-order (children in insertion order, then root).
    public var postOrder: __TreeKeyedOrder.Post.Sequence<S> {
        __TreeKeyedOrder.Post.Sequence<S>(tree: self)
    }

    /// A sequence that yields values in level-order (breadth-first).
    public var levelOrder: __TreeKeyedOrder.Level.Sequence<S> {
        __TreeKeyedOrder.Level.Sequence<S>(tree: self)
    }
}
