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

// MARK: - Map Values

extension Tree where S: __TreeKeyedStorage, S.Element: Copyable {

    /// Returns a new tree with the same structure but values transformed by the closure.
    ///
    /// - Parameter transform: A closure that maps each value to a new value.
    /// - Returns: A tree with the same keys and structure, but transformed values.
    @inlinable
    public func mapValues<U>(_ transform: (Value) -> U) -> TreeKeyed<U, Key> {
        var result = TreeKeyed<U, Key>()
        guard let rootHandle = _rootHandle else { return result }

        // Pre-order traversal to preserve structure
        var pending = Stack<(source: Store.Generational.Handle, parentHandle: Store.Generational.Handle?, parentKey: Key?)>()
        pending.push((rootHandle, nil, nil))

        while !pending.isEmpty {
            let (sourceHandle, destParentHandle, key) = pending.pop()!
            let newValue = transform(_value(of: sourceHandle))

            let handle = result._insertNode(newValue, parent: destParentHandle)

            if let destParentHandle {
                result._linkChild(handle, to: destParentHandle, at: key!)
            } else {
                result._rootHandle = handle
            }

            // Collect children in reverse for correct order
            let children = _children(of: sourceHandle)
            for i in (0..<children.count).reversed() {
                pending.push((children[i].handle, handle, children[i].key))
            }
        }

        return result
    }

    // MARK: - Map Values with Key Path

    /// Returns a new tree with values transformed by a closure that receives the key path.
    ///
    /// Delegates to ``compactMapValues(_:)-4k9z`` per [IMPL-033].
    ///
    /// - Parameter transform: A closure that receives the key path and value, returning a new value.
    /// - Returns: A tree with the same keys and structure, but transformed values.
    @inlinable
    public func mapValues<U, E>(
        _ transform: ([Key], Value) throws(E) -> U
    ) throws(E) -> TreeKeyed<U, Key> {
        try compactMapValues { (path, value) throws(E) -> U? in
            try transform(path, value)
        }
    }

    /// Returns a new tree with values transformed, optionally broadcasting the result
    /// to all descendants.
    ///
    /// When the transform returns `recursivelyApply: true`, the transformed value
    /// is assigned to the node and all its descendants without calling the transform
    /// again. When the transform returns `recursivelyApply: false`, each descendant
    /// is transformed independently.
    ///
    /// Delegates to ``compactMapValues(_:)-8r2v`` per [IMPL-033].
    ///
    /// - Parameter transform: A closure that receives the key path and value,
    ///   returning the new value and whether to broadcast it to descendants.
    /// - Returns: A tree with the same keys and structure, but transformed values.
    @inlinable
    public func mapValues<U, E>(
        _ transform: ([Key], Value) throws(E) -> (U, recursivelyApply: Bool)
    ) throws(E) -> TreeKeyed<U, Key> {
        try compactMapValues { (path, value) throws(E) in
            try transform(path, value) as (U, recursivelyApply: Bool)?
        }
    }

    // MARK: - Compact Map Values with Key Path

    /// Returns a new tree with values optionally transformed, removing nodes where
    /// the transform returns nil. The key path from root to each node is provided.
    ///
    /// When a node's transform returns nil, the node and its entire subtree are dropped.
    ///
    /// Delegates to ``compactMapValues(_:)-8r2v`` per [IMPL-033].
    ///
    /// - Parameter transform: A closure that receives the key path and value,
    ///   returning the new value or nil to drop the subtree.
    /// - Returns: A tree with transformed values, minus pruned subtrees.
    @inlinable
    public func compactMapValues<U, E>(
        _ transform: ([Key], Value) throws(E) -> U?
    ) throws(E) -> TreeKeyed<U, Key> {
        try compactMapValues { (path, value) throws(E) in
            try transform(path, value).map { ($0, recursivelyApply: false) }
        }
    }

    /// Returns a new tree with values optionally transformed, with optional broadcasting
    /// to descendants.
    ///
    /// This is the core tree-transform primitive. All other key-path-aware
    /// `mapValues` and `compactMapValues` variants delegate to this method.
    ///
    /// When the transform returns `recursivelyApply: true`, the value is broadcast
    /// to all descendants without calling the transform for each. When the transform
    /// returns nil, the node and its entire subtree are dropped.
    ///
    /// - Parameter transform: A closure that receives the key path and value,
    ///   returning the new value and broadcast flag, or nil to drop the subtree.
    /// - Returns: A tree with transformed values, minus pruned subtrees.
    /// - Complexity: O(n) where n is the number of nodes in the source tree.
    @inlinable
    public func compactMapValues<U, E>(
        _ transform: ([Key], Value) throws(E) -> (U, recursivelyApply: Bool)?
    ) throws(E) -> TreeKeyed<U, Key> {
        var result = TreeKeyed<U, Key>()
        guard let rootHandle = _rootHandle else { return result }

        var pending = Stack<
            (
                source: Store.Generational.Handle,
                destParent: Store.Generational.Handle?,
                parentKey: Key?,
                path: [Key],
                broadcast: U?
            )
        >()
        pending.push((rootHandle, nil, nil, [], nil))

        while !pending.isEmpty {
            let (sourceHandle, destParentHandle, key, path, broadcast) = pending.pop()!

            let newValue: U
            let shouldBroadcast: Bool

            if let broadcastValue = broadcast {
                newValue = broadcastValue
                shouldBroadcast = true
            } else {
                guard let transformed = try transform(path, _value(of: sourceHandle)) else {
                    continue
                }
                newValue = transformed.0
                shouldBroadcast = transformed.recursivelyApply
            }

            let handle = result._insertNode(newValue, parent: destParentHandle)

            if let destParentHandle {
                result._linkChild(handle, to: destParentHandle, at: key!)
            } else {
                result._rootHandle = handle
            }

            let children = _children(of: sourceHandle)
            for i in (0..<children.count).reversed() {
                var childPath = path
                childPath.append(children[i].key)
                pending.push(
                    (
                        children[i].handle,
                        handle,
                        children[i].key,
                        childPath,
                        shouldBroadcast ? newValue : nil
                    )
                )
            }
        }

        return result
    }

    // MARK: - Compact Map Values (Simple)

    /// Returns a new tree with values optionally transformed, removing nodes where the transform returns nil.
    ///
    /// When a non-leaf node's transform returns nil, its entire subtree is removed.
    ///
    /// - Parameter transform: A closure that optionally transforms each value.
    /// - Returns: A tree with transformed values, minus pruned subtrees.
    @inlinable
    public func compactMapValues<U>(_ transform: (Value) -> U?) -> TreeKeyed<U, Key> {
        var result = TreeKeyed<U, Key>()
        guard let rootHandle = _rootHandle else { return result }

        guard let rootValue = transform(_value(of: rootHandle)) else { return result }

        let rootDest = result._insertNode(rootValue, parent: nil)
        result._rootHandle = rootDest

        var pending = Stack<(source: Store.Generational.Handle, destParent: Store.Generational.Handle)>()
        pending.push((rootHandle, rootDest))

        while !pending.isEmpty {
            let (sourceHandle, destParentHandle) = pending.pop()!

            for (childKey, childHandle) in _children(of: sourceHandle) {
                guard let childValue = transform(_value(of: childHandle)) else { continue }

                let childDest = result._insertNode(childValue, parent: destParentHandle)
                result._linkChild(childDest, to: destParentHandle, at: childKey)

                pending.push((childHandle, childDest))
            }
        }

        return result
    }
}

// MARK: - Map Values (Async)

extension Tree where S: __TreeKeyedStorage, S.Element: Copyable {

    /// Async variant of ``mapValues(_:)-2g7k``.
    @inlinable
    public func mapValues<U, E>(
        _ transform: ([Key], Value) async throws(E) -> U
    ) async throws(E) -> TreeKeyed<U, Key> {
        try await compactMapValues { (path, value) async throws(E) -> U? in
            try await transform(path, value)
        }
    }

    /// Async variant of ``mapValues(_:)-5h3r``.
    @inlinable
    public func mapValues<U, E>(
        _ transform: ([Key], Value) async throws(E) -> (U, recursivelyApply: Bool)
    ) async throws(E) -> TreeKeyed<U, Key> {
        try await compactMapValues { (path, value) async throws(E) in
            try await transform(path, value) as (U, recursivelyApply: Bool)?
        }
    }

    /// Async variant of ``compactMapValues(_:)-4k9z``.
    @inlinable
    public func compactMapValues<U, E>(
        _ transform: ([Key], Value) async throws(E) -> U?
    ) async throws(E) -> TreeKeyed<U, Key> {
        try await compactMapValues { (path, value) async throws(E) in
            try await transform(path, value).map { ($0, recursivelyApply: false) }
        }
    }

    /// Async variant of ``compactMapValues(_:)-8r2v``.
    @inlinable
    public func compactMapValues<U, E>(
        _ transform: ([Key], Value) async throws(E) -> (U, recursivelyApply: Bool)?
    ) async throws(E) -> TreeKeyed<U, Key> {
        var result = TreeKeyed<U, Key>()
        guard let rootHandle = _rootHandle else { return result }

        var pending = Stack<
            (
                source: Store.Generational.Handle,
                destParent: Store.Generational.Handle?,
                parentKey: Key?,
                path: [Key],
                broadcast: U?
            )
        >()
        pending.push((rootHandle, nil, nil, [], nil))

        while !pending.isEmpty {
            let (sourceHandle, destParentHandle, key, path, broadcast) = pending.pop()!

            let newValue: U
            let shouldBroadcast: Bool

            if let broadcastValue = broadcast {
                newValue = broadcastValue
                shouldBroadcast = true
            } else {
                guard let transformed = try await transform(path, _value(of: sourceHandle)) else {
                    continue
                }
                newValue = transformed.0
                shouldBroadcast = transformed.recursivelyApply
            }

            let handle = result._insertNode(newValue, parent: destParentHandle)

            if let destParentHandle {
                result._linkChild(handle, to: destParentHandle, at: key!)
            } else {
                result._rootHandle = handle
            }

            let children = _children(of: sourceHandle)
            for i in (0..<children.count).reversed() {
                var childPath = path
                childPath.append(children[i].key)
                pending.push(
                    (
                        children[i].handle,
                        handle,
                        children[i].key,
                        childPath,
                        shouldBroadcast ? newValue : nil
                    )
                )
            }
        }

        return result
    }
}
