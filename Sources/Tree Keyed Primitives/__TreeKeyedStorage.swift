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

public import Hash_Primitives
public import Store_Primitive
public import Storage_Generational_Primitives
public import Tree_Primitives

// MARK: - __TreeKeyedStorage — the KEYED storage-column capability (refines __TreeStorage)
//
// The keyed tree is `Tree<S>` over a keyed column `S` ([DS-025]/[DS-027]). The shared
// `__TreeStorage` seam already carries the arena + child-link ops every column needs;
// this refinement constrains the address to a key (`Address: Hash.Protocol`) and adds the
// two reads the keyed-SPECIFIC surface needs that are not on the shared seam — the
// reverse-key info that lives only in the column's child links:
//
//   • `_parentKey(of:)` — the key under which a node sits in its parent (the O(1)-unlink
//     back-key; the source for `key(of:)` and `keyPath(to:)`).
//   • `_children(of:)` — the node's children as ordered `(key, handle)` pairs (the source
//     for `children(of:)`, `mapValues`, `prune`, `subtree`, `diff`, `zip`).
//
// The carrier's keyed-specific extensions constrain on this capability
// (`extension __Tree where S: __TreeKeyedStorage`) and reach the column through the
// public `__Tree<S>._storage` accessor (the tree-core seam). Hoisted per [API-EXC-001].

/// The keyed storage-column capability: `__TreeStorage` with a key address, plus the two
/// reverse-key reads the keyed tree's key-path surface needs.
///
/// The `Error == __TreeKeyedError<Address>` refinement pins the column's error witness
/// (P4, 2026-07-06): in every `extension __Tree where S: __TreeKeyedStorage` the carrier's
/// flow-through `Self.Error` is therefore CONCRETELY `__TreeKeyedError<S.Address>` — the
/// keyed surface can spell its typed throws through the public path instead of the
/// hoisted dunder ([API-ERR-007]).
public protocol __TreeKeyedStorage: __TreeStorage
where Address: Hash.`Protocol`, Error == __TreeKeyedError<Address> {

    /// The key under which `handle` is stored in its parent (`nil` for the root).
    func _parentKey(of handle: Store.Generational.Handle) -> Address?

    /// A node's children as ordered `(key, handle)` pairs, in insertion order.
    func _children(
        of handle: Store.Generational.Handle
    ) -> [(key: Address, handle: Store.Generational.Handle)]
}
