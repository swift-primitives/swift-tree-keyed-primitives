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

// MARK: - Prune

extension Tree.Keyed where Element: Copyable {

    /// Removes all subtrees rooted at nodes where the predicate returns true.
    ///
    /// Traverses the tree in post-order. When the predicate returns true for a
    /// node, that node and its entire subtree are removed. Surviving branches
    /// are left intact.
    ///
    /// - Parameter shouldRemove: A closure that returns true for nodes to prune.
    @inlinable
    public mutating func prune(where shouldRemove: (Value) -> Bool) {
        guard let rootHandle = _rootHandle else { return }

        // Check root first
        if shouldRemove(_value(of: rootHandle)) {
            // Remove entire tree
            if let root = self.root {
                try? removeSubtree(at: root)
            }
            return
        }

        // Collect nodes to prune via pre-order traversal
        var toPrune: [(parentHandle: Store.Generational.Handle, key: Key)] = []
        var pending = Stack<Store.Generational.Handle>()
        pending.push(rootHandle)

        while !pending.isEmpty {
            let handle = pending.pop()!

            for (childKey, childHandle) in _children(of: handle) {
                if shouldRemove(_value(of: childHandle)) {
                    toPrune.append((parentHandle: handle, key: childKey))
                } else {
                    pending.push(childHandle)
                }
            }
        }

        // Remove pruned subtrees (in reverse to avoid invalidation issues). The
        // shared `removeSubtree` default unlinks the child (O(1) via its back-key)
        // and frees the subtree post-order.
        for (parentHandle, key) in toPrune.reversed() {
            guard let childHandle = _childHandle(of: parentHandle, key: key) else { continue }
            try? removeSubtree(at: _position(of: childHandle))
        }
    }
}
