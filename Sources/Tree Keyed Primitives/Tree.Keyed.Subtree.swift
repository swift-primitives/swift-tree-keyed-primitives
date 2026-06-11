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

public import Store_Primitive
public import Storage_Generational_Primitives
public import Stack_Primitive

// MARK: - Subtree Extraction

extension Tree.Keyed where Element: Copyable {

    /// Returns a deep copy of the subtree rooted at the given key path.
    ///
    /// Named `subtree(at:)` per [API-NAME-002] — Graph's `subgraph(at:)` uses
    /// graph terminology; `subtree` matches tree terminology.
    ///
    /// For read-only analysis of a subtree, prefer `position(at:)` with
    /// navigation methods (O(1) vs O(n) copy). Use `subtree(at:)` when you
    /// need a standalone tree to pass to other functions or preserve across
    /// mutations.
    ///
    /// - Parameter keyPath: The sequence of keys from root to the subtree root.
    /// - Returns: A standalone tree containing the subtree, or nil if the path
    ///   doesn't resolve.
    /// - Complexity: O(d + n) where d is key path length, n is subtree node count.
    @inlinable
    public func subtree(at keyPath: some Swift.Sequence<Key>) -> Tree<Element>.Keyed<Key>? {
        guard let pos = position(at: keyPath) else { return nil }
        guard let sourceHandle = try? _handle(pos) else { return nil }

        var result = Tree<Element>.Keyed<Key>()

        let rootDest = result._insert(node: Node(value: _node(sourceHandle) { $0.value }))
        result._rootHandle = rootDest

        var pending = Stack<(source: Store.Generational.Handle, dest: Store.Generational.Handle)>()
        pending.push((sourceHandle, rootDest))

        while !pending.isEmpty {
            let (srcHandle, dstHandle) = pending.pop()!

            for (childKey, childHandle) in _children(of: srcHandle) {
                let newChild = result._insert(
                    node: Node(value: _node(childHandle) { $0.value }, parentHandle: dstHandle, parentKey: childKey)
                )
                result._link(parent: dstHandle, key: childKey, child: newChild)
                pending.push((childHandle, newChild))
            }
        }

        return result
    }
}
