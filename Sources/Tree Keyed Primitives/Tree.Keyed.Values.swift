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

// MARK: - Values Along Key Path

extension Tree.Keyed where Element: Copyable {

    /// Returns values at each step along the key path.
    ///
    /// For each key in the path, yields the value at the child node reached
    /// by that key. If the child doesn't exist, yields nil. Once a missing
    /// child is encountered, all subsequent values are nil.
    ///
    /// Named `values(along:)` per [API-NAME-002] — Graph's `takeValues(at:)`
    /// is a compound name not in stdlib.
    ///
    /// - Parameter keyPath: The keys to walk from the root.
    /// - Returns: An array of optional values, one per key.
    /// - Complexity: O(d) where d is the length of the key path.
    @inlinable
    public func values(
        along keyPath: some Swift.Sequence<Key>
    ) -> [Value?] {
        guard let rootHandle = _rootHandle else { return [] }

        var result: [Value?] = []
        var currentHandle: Store.Generational.Handle? = rootHandle

        for key in keyPath {
            guard let handle = currentHandle else {
                result.append(nil)
                continue
            }

            if let childHandle = _childHandle(of: handle, key: key) {
                result.append(_node(childHandle) { $0.value })
                currentHandle = childHandle
            } else {
                result.append(nil)
                currentHandle = nil
            }
        }

        return result
    }
}
