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

// MARK: - Hoisted keyed traversal-order namespace (module level)
//
// The keyed tree's value-`Sequence` traversal views ([DS-027]). The shared closure
// traversal (`tree.forEach.preOrder { }`) is inherited from the tree-core engine; these
// views are the `Iterable` / `Sequenceable` collection path (`Array(tree.preOrder)`).
// Hoisted and generic over the keyed column `S` (per [API-EXC-001], like ``__TreeKeyedLinks``
// / ``__TreeKeyedError``): they cannot nest in the generic `Tree<S>`, and the column-nested
// alternative would block the `tree.preOrder` property accessor.

/// Namespace for the keyed tree's traversal-order sequence views.
///
/// - ``Pre``: pre-order (root, then children in insertion order)
/// - ``Post``: post-order (children in insertion order, then root)
/// - ``Level``: level-order (breadth-first)
public enum __TreeKeyedOrder {}
