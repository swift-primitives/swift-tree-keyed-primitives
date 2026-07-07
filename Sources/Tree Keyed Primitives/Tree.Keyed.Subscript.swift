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

// MARK: - Subscript (Read-Only)

extension __Tree where S: __TreeKeyedStorage, S.Element: Copyable {

    /// Returns the value at the given key path, or nil if the path doesn't resolve.
    ///
    /// - Parameter keyPath: The keys from root to the target node.
    /// - Returns: The value at the key path, or nil.
    /// - Complexity: O(d) where d is the length of the key path.
    @_disfavoredOverload
    @inlinable
    public subscript(keyPath: [Key]) -> Value? {
        value(at: keyPath)
    }

    /// Returns the value at the given key path, or nil if the path doesn't resolve.
    ///
    /// - Parameter keyPath: The keys from root to the target node.
    /// - Returns: The value at the key path, or nil.
    /// - Complexity: O(d) where d is the length of the key path.
    @_disfavoredOverload
    @inlinable
    public subscript(keyPath: Key...) -> Value? {
        self[keyPath]
    }
}

// MARK: - Subscript (Sparse)

extension __Tree where S: __TreeKeyedStorage, S.Element: Copyable {

    /// Gets or sets the value at the given key path in a sparse tree.
    ///
    /// On get, returns the value at the key path, or nil if the node doesn't exist.
    /// On set, creates the root and intermediate nodes with nil values as needed.
    ///
    /// For empty key path, targets the root node. Creates the root if needed.
    /// Assigns `Optional.none` explicitly when `newValue` is nil.
    ///
    /// - Parameter keyPath: The keys from root to the target node.
    /// - Returns: The value at the key path (which may itself be nil), or nil if the node doesn't exist.
    /// - Complexity: O(d) where d is the length of the key path.
    @inlinable
    public subscript<U>(keyPath: [Key]) -> U? where Value == U? {
        get {
            // `value(at:)` returns `Value?` = `U??` here; the `?? nil` FLATTENS the
            // double optional to the subscript's `U?` — removing it would change the
            // type. Known redundant_nil_coalescing false-positive class (trap table).
            // swiftlint:disable:next redundant_nil_coalescing
            value(at: keyPath) ?? nil
        }
        set {
            // Fire-and-forget by contract: the sparse setter mirrors
            // `Swift.Dictionary`'s subscript — intermediate nodes are created as
            // needed, so the structural failure modes are unreachable and any
            // would-be error is intentionally discarded.
            if keyPath.isEmpty {
                if root != nil {
                    do throws(Self.Error) {
                        try update(newValue, at: keyPath)
                    } catch {
                        // Unreachable: root was just checked non-nil.
                    }
                } else {
                    do throws(Self.Error) {
                        _ = try insert(newValue, at: Insert.Position.root)
                    } catch {
                        // Unreachable: root was just checked nil.
                    }
                }
            } else {
                do throws(Self.Error) {
                    _ = try insert(newValue, at: keyPath)
                } catch {
                    // Unreachable: the sparse insert creates every missing node.
                }
            }
        }
    }

    /// Gets or sets the value at the given key path in a sparse tree.
    ///
    /// Variadic overload of ``subscript(_:)-2k3j``.
    @inlinable
    public subscript<U>(keyPath: Key...) -> U? where Value == U? {
        get { self[keyPath] }
        set { self[keyPath] = newValue }
    }
}

// MARK: - Sparse Insert Convenience

extension __Tree where S: __TreeKeyedStorage, S.Element: Copyable {

    /// Inserts a value at the given key path, creating intermediate nodes with nil values.
    ///
    /// If the tree is empty, creates the root with nil. If intermediate nodes along
    /// the path don't exist, they are created with nil values.
    ///
    /// Returns the position of the inserted (or updated) node. Unlike Graph's
    /// `insertValue` which returns the old value, Tree.Keyed returns the position
    /// for consistency with position-based navigation.
    ///
    /// - Parameters:
    ///   - value: The value to insert at the terminal key.
    ///   - keyPath: The keys from root to the insertion point.
    /// - Returns: The position of the inserted or updated node.
    /// - Throws: ``__TreeKeyedError/rootOccupied`` / ``__TreeKeyedError/invalidPosition``
    ///   from the underlying keyed insert, if the path resolution races a stale position.
    @inlinable
    @discardableResult
    public mutating func insert<U>(
        _ value: U?,
        at keyPath: [Key]
    ) throws(Self.Error) -> Position where Value == U? {
        if keyPath.isEmpty {
            guard let root else {
                return try insert(value, at: Insert.Position.root)
            }
            try update(value, at: keyPath)
            return root
        }
        return try insert(value, at: keyPath, intermediateValue: { _ in nil })
    }
}
