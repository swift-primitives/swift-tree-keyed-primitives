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
public import Tree_Primitives

// MARK: - Tree<Element>.Keyed<Key> — the KEYED-column front door ([DS-028])

extension __Tree where S: ~Copyable, S: __TreeStorage {

    /// The keyed (dictionary-indexed) tree: the family carrier over the keyed column.
    ///
    /// A column-selection front-door alias ([DS-028], the D4.1 sibling-column sense):
    /// it re-parameterizes the carrier onto `TreeStorage.Keyed`, inheriting `Element`
    /// (`S.Element`) from the family member it is named on — `Tree<Int>.Keyed<String>`
    /// resolves through the canonical alias to
    /// `__Tree<TreeStorage.Keyed<Int, String>>`, fully specialized, zero forwarding.
    /// Children are addressed by unique `Key` (`Address == Key`) rather than by dense
    /// child index; the keyed column is a SIBLING column with its own package, not a
    /// variant axis of the dynamic column.
    ///
    /// The `where S: ~Copyable` restatement keeps the alias reachable from move-only
    /// columns (the M1 alias-reachability discipline); `S: __TreeStorage` supplies
    /// `S.Element`. It supersedes the retired `TreeKeyed` compound ergonomic alias
    /// (the §9.6.5 [API-NAME-001] hygiene class).
    ///
    /// ```swift
    /// var tree = Tree<Int>.Keyed<String>()
    /// let root = try tree.insert(0, at: .root)
    /// let child = try tree.insert(1, at: .child(of: root, key: "left"))
    /// ```
    public typealias Keyed<Key: Hash.`Protocol`> = __Tree<TreeStorage.Keyed<S.Element, Key>>
}
