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
        guard let rootIndex = _rootIndex else { return }
        makeUnique()

        // Check root first
        if shouldRemove(_arena[rootIndex].value) {
            // Remove entire tree
            if let root = self.root {
                try? removeSubtree(at: root)
            }
            return
        }

        // Collect nodes to prune via pre-order traversal
        var toPrune: [(parentIndex: Index<Node>, key: Key)] = []
        var pending = Stack<Index<Node>>()
        pending.push(rootIndex)

        while !pending.isEmpty {
            let index = pending.pop()!

            var children: [(key: Key, index: Index<Node>)] = []
            _arena[index]._children.forEach { key, childIndex in
                children.append((key, childIndex))
            }

            for (childKey, childIndex) in children {
                if shouldRemove(_arena[childIndex].value) {
                    toPrune.append((parentIndex: index, key: childKey))
                } else {
                    pending.push(childIndex)
                }
            }
        }

        // Remove pruned subtrees (in reverse to avoid invalidation issues)
        for (parentIndex, key) in toPrune.reversed() {
            guard let childIndex = _arena[parentIndex]._children[key] else { continue }

            // Remove child from parent's dictionary
            _arena[parentIndex]._children.remove(key)

            // Free the subtree
            var freePending = Stack<Index<Node>>()
            var freeOutput = Stack<Index<Node>>()
            freePending.push(childIndex)

            while !freePending.isEmpty {
                let current = freePending.pop()!
                freeOutput.push(current)
                _arena[current]._children.forEach { _, grandchildIndex in
                    freePending.push(grandchildIndex)
                }
            }

            while !freeOutput.isEmpty {
                let idx = freeOutput.pop()!
                _arena.free(at: idx)
            }
        }
    }
}
