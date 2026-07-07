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

public import Tree_Primitives

// MARK: - Hoisted Insert namespace (module level) — the `Tree.Keyed.Insert` vocabulary
//
// Swift does not allow nested types inside generic types to be easily accessed, so the
// keyed-insert vocabulary namespace is hoisted to module level and surfaced via the
// `Insert` nest alias below. `Tree.Keyed.Insert.Position` is the [API-NAME-001]/[API-NAME-002]
// decomposition of the former compound `InsertPosition`: it AVOIDS the collision a nested
// `Tree.Keyed.InsertPosition` would cause by redeclaring the shared `Tree.Protocol`
// `InsertPosition` member (`__TreeInsertPosition<Address>`). Hoisted per [API-EXC-001].

/// Hoisted implementation of the keyed-insert vocabulary namespace (``Tree/Keyed/Insert``).
///
/// - Note: Use ``Tree/Keyed/Insert`` in your code, not this type directly.
public enum __TreeKeyedInsert<Key: Hash.`Protocol`> {

    /// Where to insert a new node in a keyed tree (``Tree/Keyed/Insert/Position``).
    public typealias Position = __TreeKeyedInsertPosition<Key>
}

// MARK: - Tree.Keyed.Insert — the nest alias onto the keyed carrier

extension __Tree where S: __TreeKeyedStorage {

    /// The keyed-insert vocabulary namespace: ``Tree/Keyed/Insert/Position`` names where to
    /// insert a new node (the [API-NAME-002] decomposition of the former `InsertPosition`).
    ///
    /// Hosted on the `S: __TreeKeyedStorage` surface (the keyed-specific column capability,
    /// which is Copyable-constrained — no `~Copyable` restatement, matching the keyed insert /
    /// helper / key-path extensions this alias serves).
    public typealias Insert = __TreeKeyedInsert<S.Address>
}

// MARK: - Keyed insert (the keyed error-mapping wrapper over the shared insert)

extension __Tree where S: __TreeKeyedStorage {

    /// Inserts a value at the specified keyed position.
    ///
    /// A thin wrapper that delegates orchestration to the shared `Tree<S>` insert and
    /// re-maps its `__TreeError` into the richer keyed error, re-attaching the key for
    /// the occupied-child case.
    ///
    /// - Throws: ``__TreeKeyedError/rootOccupied`` if inserting at root when it exists,
    ///   ``__TreeKeyedError/invalidPosition`` if the parent position is invalid or stale,
    ///   ``__TreeKeyedError/keyOccupied(_:)`` if the child key already exists at the parent.
    @inlinable
    @discardableResult
    public mutating func insert(
        _ value: consuming Value,
        at position: Insert.Position
    ) throws(Self.Error) -> Position {
        switch position {
        case .root:
            do {
                return try insert(value, at: __TreeInsertPosition<Key>.root)
            } catch {
                throw Self._map(error)
            }

        case .child(of: let parent, let key):
            do {
                return try insert(value, at: __TreeInsertPosition<Key>.child(of: parent, at: key))
            } catch {
                throw Self._map(error, key: key)
            }
        }
    }

    /// Translates a shared `__TreeError` into the richer keyed error, re-attaching the
    /// key for the occupied-child case. `.slotOccupied` only arises on the `.child` path.
    @inlinable
    static func _map(_ error: __TreeError, key: Key? = nil) -> __TreeKeyedError<Key> {
        switch error {
        case .slotOccupied: return key.map { .keyOccupied($0) } ?? .invalidPosition
        case .rootOccupied: return .rootOccupied
        case .invalidPosition: return .invalidPosition
        case .cannotRemoveNonLeaf: return .cannotRemoveNonLeaf
        case .childIndexOutOfBounds: return .invalidPosition
        }
    }
}

// MARK: - Copyable value operations (update / rootValue)

extension __Tree where S: __TreeKeyedStorage, S.Element: Copyable {

    /// The root node's value, or `nil` if the tree is empty.
    ///
    /// Setting to a non-`nil` value updates the root (or creates it if empty). Setting
    /// to `nil` is a no-op — the setter exists for optional-chaining writeback.
    @inlinable
    public var rootValue: Value? {
        get {
            guard let rootHandle = _rootHandle else { return nil }
            return _value(of: rootHandle)
        }
        set {
            guard let newValue else { return }
            if let rootHandle = _rootHandle {
                _setValue(at: rootHandle, newValue)
            } else {
                _rootHandle = _insertNode(newValue, parent: nil)
            }
        }
    }

    /// Replaces the value at the specified position.
    ///
    /// - Throws: ``__TreeKeyedError/invalidPosition`` if the position is invalid or stale.
    @inlinable
    public mutating func update(
        at position: Position,
        _ newValue: Value
    ) throws(Self.Error) {
        guard let handle = _liveHandle(position) else { throw .invalidPosition }
        _setValue(at: handle, newValue)
    }
}
