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

public import Storage_Generational_Primitives
public import Store_Primitive

// MARK: - The keyed arena node (non-public arena detail)
//
// The generational-column slot type, generalized over the per-conformer child-link
// representation `ChildLinks` (the keyed ordered dictionary + back-key for this
// package). This is a verbatim local copy of the tree-core `__TreeNode` ([DS-025]):
// that type is `@usableFromInline` INTERNAL to swift-tree-primitives, so a separate
// column package cannot name it and must carry its own arena nucleus, composed from
// the same public generational-column primitives. It never appears in any public
// signature, so it is `@usableFromInline`, not `public`.

@usableFromInline
struct __TreeNode<Element: ~Copyable, ChildLinks>: ~Copyable {
    /// The element stored in this node.
    @usableFromInline var element: Element
    /// The node's child links, in the conformer's representation.
    @usableFromInline var links: ChildLinks
    /// The handle of this node's parent (`nil` for the root).
    @usableFromInline var parentHandle: Store.Generational.Handle?

    @usableFromInline
    init(
        element: consuming Element,
        links: consuming ChildLinks,
        parentHandle: Store.Generational.Handle?
    ) {
        self.element = element
        self.links = links
        self.parentHandle = parentHandle
    }
}

extension __TreeNode: Copyable where Element: Copyable, ChildLinks: Copyable {}

// Conditionally Sendable when its stored element + links are (the parent handle is
// always Sendable).
extension __TreeNode: Sendable where Element: Sendable, ChildLinks: Sendable {}
