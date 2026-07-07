// swift-format-ignore-file: AmbiguousTrailingClosureOverload
//
// The two `forEach(_:)` overloads below are distinguished by their closure's
// effect signature (sync vs async) — the standard sync/async overload family
// (P2b carve-out). swift-format's syntactic check sees only the shared base
// name; call sites resolve unambiguously on the closure's shape.
//
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

// MARK: - ForEach with Key Path

extension __Tree where S: __TreeKeyedStorage, S.Element: Copyable {

    /// Iterates over all nodes in pre-order, passing the key path and value to the closure.
    ///
    /// Each node receives its full root-to-node key path. Children are visited
    /// in insertion order.
    ///
    /// - Parameter body: A closure called with the key path and value at each node.
    /// - Throws: Whatever `body` throws, propagated from the first failing node.
    /// - Complexity: O(n) where n is the number of nodes.
    @inlinable
    public func forEach<E>(
        _ body: ([Key], Value) throws(E) -> Void
    ) throws(E) {
        guard let rootHandle = _rootHandle else { return }

        var pending = Stack<(handle: Store.Generational.Handle, path: [Key])>()
        pending.push((rootHandle, []))

        while let (handle, path) = pending.pop() {
            try body(path, _value(of: handle))

            let children = _children(of: handle)
            for i in (0..<children.count).reversed() {
                var childPath = path
                childPath.append(children[i].key)
                pending.push((children[i].handle, childPath))
            }
        }
    }

    /// Async variant of ``forEach(_:)-7k3x``.
    @inlinable
    public func forEach<E>(
        _ body: ([Key], Value) async throws(E) -> Void
    ) async throws(E) {
        guard let rootHandle = _rootHandle else { return }

        var pending = Stack<(handle: Store.Generational.Handle, path: [Key])>()
        pending.push((rootHandle, []))

        while let (handle, path) = pending.pop() {
            try await body(path, _value(of: handle))

            let children = _children(of: handle)
            for i in (0..<children.count).reversed() {
                var childPath = path
                childPath.append(children[i].key)
                pending.push((children[i].handle, childPath))
            }
        }
    }
}
