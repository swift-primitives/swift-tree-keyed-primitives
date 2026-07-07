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

public import Stack_Primitive
public import Storage_Generational_Primitives
public import Store_Primitive

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
public func zip<Key: Hash.`Protocol`, A: Copyable, B: Copyable>(
    _ lhs: Tree<A>.Keyed<Key>,
    _ rhs: Tree<B>.Keyed<Key>
) -> Tree<(A, B)>.Keyed<Key> {
    var result = Tree<(A, B)>.Keyed<Key>()

    guard let lhsRoot = lhs._rootHandle, let rhsRoot = rhs._rootHandle else {
        return result
    }

    let rootDest = result._insertNode(
        (lhs._value(of: lhsRoot), rhs._value(of: rhsRoot)),
        parent: nil
    )
    result._rootHandle = rootDest

    var pending = Stack<
        (
            lhsHandle: Store.Generational.Handle,
            rhsHandle: Store.Generational.Handle,
            destParent: Store.Generational.Handle
        )
    >()
    pending.push((lhsRoot, rhsRoot, rootDest))

    while let (lhsHandle, rhsHandle, destParentHandle) = pending.pop() {
        // For each child key in lhs, check if rhs also has it
        for (key, lhsChild) in lhs._children(of: lhsHandle) {
            guard let rhsChild = rhs._childHandle(of: rhsHandle, key: key) else { continue }

            let childDest = result._insertNode(
                (lhs._value(of: lhsChild), rhs._value(of: rhsChild)),
                parent: destParentHandle
            )
            result._linkChild(childDest, to: destParentHandle, at: key)

            pending.push((lhsChild, rhsChild, childDest))
        }
    }

    return result
}
