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
public import Tree_Primitives

// MARK: - Key Path Operations

extension __Tree where S: __TreeKeyedStorage {

    /// Reconstructs the key path from the root to the given position.
    ///
    /// Walks up the parent chain collecting `parentKey` values, then reverses.
    ///
    /// - Parameter position: The position of the node.
    /// - Returns: The key path from root to node, or `nil` if position is invalid.
    ///   Returns an empty array for the root node.
    /// - Complexity: O(d) where d is the depth of the node.
    @inlinable
    public func keyPath(to position: Position) -> [Key]? {
        guard let handle = _liveHandle(position) else { return nil }

        var path: [Key] = []
        var current = handle

        while let parentKey = _parentKey(of: current) {
            path.append(parentKey)
            guard let parentHandle = _parentHandle(of: current) else {
                break
            }
            current = parentHandle
        }

        path.reverse()
        return path
    }

    /// Returns the position of the node at the given key path.
    ///
    /// - Parameter keyPath: The sequence of keys from root to the target node.
    /// - Returns: The position of the node, or `nil` if any key in the path is not found
    ///   or the tree is empty.
    /// - Complexity: O(d) where d is the length of the key path.
    @inlinable
    public func position(at keyPath: some Swift.Sequence<Key>) -> Position? {
        guard let rootHandle = _rootHandle else { return nil }

        var current = rootHandle
        for key in keyPath {
            guard let childHandle = _childHandle(of: current, key: key) else {
                return nil
            }
            current = childHandle
        }

        return _position(of: current)
    }
}

// MARK: - Key Path Operations (Copyable)

extension __Tree where S: __TreeKeyedStorage, S.Element: Copyable {

    /// Returns the value at the given key path.
    ///
    /// - Parameter keyPath: The sequence of keys from root to the target node.
    /// - Returns: The value at the key path, or `nil` if any key is not found.
    /// - Complexity: O(d) where d is the length of the key path.
    @inlinable
    public func value(at keyPath: some Swift.Sequence<Key>) -> Value? {
        guard let pos = position(at: keyPath) else { return nil }
        return peek(at: pos)
    }

    /// Replaces the value at the given key path.
    ///
    /// - Parameters:
    ///   - newValue: The new value.
    ///   - keyPath: The sequence of keys from root to the target node.
    /// - Throws: ``Error/invalidPosition`` if the key path does not resolve to a node.
    @inlinable
    public mutating func update(_ newValue: Value, at keyPath: some Swift.Sequence<Key>) throws(Self.Error) {
        guard let pos = position(at: keyPath) else {
            throw .invalidPosition
        }
        try update(at: pos, newValue)
    }

    /// Inserts a value at the given key path, creating intermediate nodes as needed.
    ///
    /// If intermediate nodes along the path do not exist, they are created with
    /// the value provided by `intermediateValue`. If the root does not exist,
    /// it is created using `intermediateValue` with the first key.
    ///
    /// - Parameters:
    ///   - value: The value to insert at the terminal key.
    ///   - keyPath: The sequence of keys from root to the insertion point.
    ///     Must be non-empty.
    ///   - intermediateValue: A closure that provides values for intermediate nodes
    ///     that need to be created. Called with the key of each intermediate node.
    /// - Returns: The position of the newly inserted (or updated) node.
    @inlinable
    @discardableResult
    public mutating func insert(
        _ value: Value,
        at keyPath: [Key],
        intermediateValue: (Key) -> Value
    ) throws(Self.Error) -> Position {
        precondition(!keyPath.isEmpty, "Key path must not be empty")

        // Ensure root exists
        if _rootHandle == nil {
            _rootHandle = _insertNode(intermediateValue(keyPath[0]), parent: nil)
        }

        var currentHandle = _rootHandle!

        // Walk down to the parent of the terminal node, creating intermediates
        for i in keyPath.indices.dropLast() {
            let key = keyPath[i]
            if let childHandle = _childHandle(of: currentHandle, key: key) {
                currentHandle = childHandle
            } else {
                let handle = _insertNode(intermediateValue(key), parent: currentHandle)
                _linkChild(handle, to: currentHandle, at: key)
                currentHandle = handle
            }
        }

        // Insert or update terminal node
        let terminalKey = keyPath.last!
        if let existingChild = _childHandle(of: currentHandle, key: terminalKey) {
            _setValue(at: existingChild, value)
            return _position(of: existingChild)
        } else {
            let handle = _insertNode(value, parent: currentHandle)
            _linkChild(handle, to: currentHandle, at: terminalKey)
            return _position(of: handle)
        }
    }
}
