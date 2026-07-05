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
        at position: __TreeKeyedInsertPosition<Key>
    ) throws(__TreeKeyedError<Key>) -> Position {
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
    ) throws(__TreeKeyedError<Key>) {
        guard let handle = _liveHandle(position) else { throw .invalidPosition }
        _setValue(at: handle, newValue)
    }
}
