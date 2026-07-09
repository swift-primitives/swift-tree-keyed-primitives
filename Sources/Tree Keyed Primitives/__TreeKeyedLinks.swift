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

public import Column_Primitives
public import Dictionary_Ordered_Primitive
public import Dictionary_Primitive
public import Hash_Indexed_Primitive
public import Ownership_Shared_Primitive
public import Storage_Generational_Primitives
public import Store_Primitive

// MARK: - Hoisted keyed child-links (module level)
//
// The per-conformer `ChildLinks` representation for `Tree.Keyed`: the ordered
// keyed-children column PLUS the `parentKey` back-key. Bundled here (A1) so the
// shared `__TreeNode` stays Key-agnostic — the keyed tree's two extra node
// properties (the children dictionary and the parent-key back-pointer) live in the
// `ChildLinks` the arena is generic over, never in `__TreeNode`. This preserves
// O(d) `keyPath(to:)`, O(1) `key(of:)`, and O(1) unlink (via the back-key).
//
// `@usableFromInline` internal: it appears only in `Tree.Keyed`'s private
// `_storage` (`Tree.Storage<__TreeKeyedLinks<Key>>`), never in the public surface.
// Unconditionally `Copyable` (`Key: Hash.Protocol ⇒ Copyable`; the children column
// is a `Copyable` `Shared`/CoW dictionary), so `Tree.Keyed` is `Copyable` exactly
// when its `Element` is.

@usableFromInline
struct __TreeKeyedLinks<Key: Hash.`Protocol`> {

    /// The ordered keyed-children column: an insertion-ordered hashed dictionary
    /// mapping child keys to node handles, providing O(1) keyed lookup and
    /// insertion-order iteration.
    ///
    /// The `Shared` (CoW) column flavor — `Key` and `Handle` are always `Copyable`,
    /// so the clone strategy is captured unconditionally and per-node child tables
    /// detach lazily when a CoW'd tree mutates them.
    @usableFromInline
    typealias Children = __DictionaryOrdered<
        Ownership.Shared<
            Hash.Entry<Key, Store.Generational.Handle>,
            Hash.Indexed<Column.Heap<Hash.Entry<Key, Store.Generational.Handle>>>
        >
    >

    /// Children indexed by key (insertion-ordered).
    @usableFromInline var children: Children

    /// The key under which this node is stored in its parent (`nil` for the root) —
    /// the O(1)-unlink back-key and the `keyPath(to:)` / `key(of:)` source.
    @usableFromInline var parentKey: Key?

    /// Creates childless links with no parent key.
    ///
    /// The arena's per-node seed; the parent key is set by `_linkChild`'s both-sides
    /// invariant when the node is linked.
    @inlinable
    package init() {
        self.children = Children()
        self.parentKey = nil
    }
}

// MARK: - Sendable (the foundation of Tree.Keyed's PROPER Sendable chain)

extension __TreeKeyedLinks: Sendable where Key: Sendable {}
