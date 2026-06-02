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

public import Buffer_Arena_Primitive
public import Dictionary_Ordered_Primitives
public import Queue_Primitives
public import Stack_Primitive

// MARK: - Zip (Structural Intersection)

/// Returns a new tree containing only nodes present in both trees (structural intersection).
///
/// For each node at a given key path, if both trees have a node at that path,
/// the result contains a node with both values paired. Branches that exist in
/// only one tree are dropped.
///
/// - Parameters:
///   - lhs: The first keyed tree.
///   - rhs: The second keyed tree.
/// - Returns: A tree whose structure is the intersection, with paired values.
@inlinable
public func zip<Key: Hash.`Protocol`, A, B>(
    _ lhs: Tree<A>.Keyed<Key>,
    _ rhs: Tree<B>.Keyed<Key>
) -> Tree<(A, B)>.Keyed<Key> {
    var result = Tree<(A, B)>.Keyed<Key>()

    guard let lhsRoot = lhs._rootIndex, let rhsRoot = rhs._rootIndex else {
        return result
    }

    let rootPos = result._arena.insert(
        Tree<(A, B)>.Keyed<Key>.Node(
            value: (lhs._arena[lhsRoot].value, rhs._arena[rhsRoot].value)
        )
    )
    result._rootIndex = rootPos.slot

    var pending = Stack<
        (
            lhsIndex: Index<Tree<A>.Keyed<Key>.Node>,
            rhsIndex: Index<Tree<B>.Keyed<Key>.Node>,
            destParent: Index<Tree<(A, B)>.Keyed<Key>.Node>
        )
    >()
    pending.push((lhsRoot, rhsRoot, rootPos.slot))

    while !pending.isEmpty {
        let (lhsIndex, rhsIndex, destParentIndex) = pending.pop()!

        // For each child key in lhs, check if rhs also has it
        lhs._arena[lhsIndex]._children.forEach { key, lhsChildIndex in
            guard let rhsChildIndex = rhs._arena[rhsIndex]._children[key] else { return }

            let childPos = result._arena.insert(
                Tree<(A, B)>.Keyed<Key>.Node(
                    value: (lhs._arena[lhsChildIndex].value, rhs._arena[rhsChildIndex].value),
                    parentIndex: destParentIndex,
                    parentKey: key
                )
            )
            result._arena[destParentIndex]._children.set(key, childPos.slot)

            pending.push((lhsChildIndex, rhsChildIndex, childPos.slot))
        }
    }

    return result
}
