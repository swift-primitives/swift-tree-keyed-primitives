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
public import Tree_Primitives

extension __TreeKeyedOrder.Post {

    /// A sequence that yields values in post-order traversal.
    ///
    /// Post-order traversal visits children in insertion order, then the root.
    @frozen
    public struct Sequence<S: __TreeKeyedStorage> {
        @usableFromInline
        let tree: Tree<S>

        @usableFromInline
        init(tree: Tree<S>) { self.tree = tree }
    }
}

// MARK: - Iterable (multipass, borrowing)

extension __TreeKeyedOrder.Post.Sequence: Iterable where S.Element: Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator =
        Iterator_Primitive.Iterator.Materializing<__TreeKeyedOrder.Post.Iterator<S>>

    @_lifetime(borrow self)
    @_implements(Iterable, makeIterator())
    public borrowing func iterableMakeIterator()
        -> Iterator_Primitive.Iterator.Materializing<__TreeKeyedOrder.Post.Iterator<S>>
    {
        Iterator_Primitive.Iterator.Materializing(__TreeKeyedOrder.Post.Iterator<S>(tree: tree))
    }
}

// MARK: - Sequenceable (single-pass, consuming)

extension __TreeKeyedOrder.Post.Sequence: Sequenceable where S.Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = __TreeKeyedOrder.Post.Iterator<S>

    public consuming func makeIterator() -> __TreeKeyedOrder.Post.Iterator<S> {
        __TreeKeyedOrder.Post.Iterator<S>(tree: tree)
    }
}
