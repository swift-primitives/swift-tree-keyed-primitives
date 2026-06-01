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

public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives
public import Sequence_Primitives

extension Tree.Keyed.Order.Pre {

    /// A sequence that yields values in pre-order traversal.
    ///
    /// Pre-order traversal visits the root first, then children in insertion order.
    public struct Sequence {
        let tree: Tree<Element>.Keyed<Key>
    }
}

// MARK: - Iterable (multipass, borrowing)
//
// Both `Iterable` and `Sequenceable` declare `associatedtype Iterator`, which Swift unifies; the
// dual conformer splits the two bindings with `@_implements`. The scalar iterator is the sibling
// `Tree.Keyed.Order.Pre.Iterator` — referenced fully-qualified so the bare name `Iterator` does not
// resolve to `Self.Iterator` (the associated type being defined).

extension Tree.Keyed.Order.Pre.Sequence: Iterable where Element: Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator =
        Iterator_Primitive.Iterator.Materializing<Tree<Element>.Keyed<Key>.Order.Pre.Iterator>

    @_lifetime(borrow self)
    @_implements(Iterable, makeIterator())
    public borrowing func iterableMakeIterator()
        -> Iterator_Primitive.Iterator.Materializing<Tree<Element>.Keyed<Key>.Order.Pre.Iterator>
    {
        Iterator_Primitive.Iterator.Materializing(Tree<Element>.Keyed<Key>.Order.Pre.Iterator(tree: tree))
    }
}

// MARK: - Sequenceable (single-pass, consuming)

extension Tree.Keyed.Order.Pre.Sequence: Sequenceable where Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Tree<Element>.Keyed<Key>.Order.Pre.Iterator

    public consuming func makeIterator() -> Tree<Element>.Keyed<Key>.Order.Pre.Iterator {
        Tree<Element>.Keyed<Key>.Order.Pre.Iterator(tree: tree)
    }
}
