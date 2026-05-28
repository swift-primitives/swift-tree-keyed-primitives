# Tree Keyed Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

The **keyed tree discipline** over the `Tree` namespace: arena-backed, dictionary-indexed tree storage with O(1) child lookup by key, token-validated positions, and three traversal orders — pre-order, post-order, and level-order.

---

## Quick Start

```swift
import Tree_Keyed_Primitives

// Build a small file-system-like hierarchy.
var tree = Tree<String>.Keyed<String>()
let root   = try tree.insert("Documents",  at: .root)
let work   = try tree.insert("Work",       at: .child(of: root, key: "work"))
let photos = try tree.insert("Photos",     at: .child(of: root, key: "photos"))
_          = try tree.insert("Report.pdf", at: .child(of: work, key: "report"))
_          = try tree.insert("Vacation",   at: .child(of: photos, key: "vacation"))

// Pre-order traversal — root before children, children in insertion order.
tree.forEachPreOrder { name in
    print(name)   // Documents, Work, Report.pdf, Photos, Vacation
}

// Key-path lookup — O(d) descent from root.
let value = tree.value(at: ["photos", "vacation"])   // "Vacation"

// Token-validated peek — returns nil for stale positions.
let preview = tree.peek(at: work)                    // "Work"
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-tree-keyed-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Tree Keyed Primitives", package: "swift-tree-keyed-primitives"),
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3
and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the matching Linux toolchain).

---

## Key Types

| Type | Purpose |
|------|---------|
| `Tree<Value>.Keyed<Key>` | The primary keyed tree value type; arena-backed, supports `~Copyable` elements and copy-on-write for `Copyable` elements |
| `Tree<Value>.Keyed<Key>.Node` | A single node — holds a value, insertion-ordered children dictionary, and optional parent back-link |
| `Tree<Value>.Keyed<Key>.InsertPosition` | Typed insertion target: `.root` or `.child(of:key:)` |
| `Tree<Value>.Keyed<Key>.Error` | Typed errors thrown by mutating operations (`rootOccupied`, `invalidPosition`, `keyOccupied`, `cannotRemoveNonLeaf`, …) |
| `Tree<Value>.Keyed<Key>.Diff` | Set of structural and value changes between two trees, produced by `diff(from:to:)` |
| `Tree<Value>.Keyed<Key>.Order.Pre.Sequence` | `Sequence` that yields values depth-first, root before children |
| `Tree<Value>.Keyed<Key>.Order.Post.Sequence` | `Sequence` that yields values depth-first, children before root |
| `Tree<Value>.Keyed<Key>.Order.Level.Sequence` | `Sequence` that yields values breadth-first by level |

---

## Related Packages

- `swift-tree-primitives` — the `Tree` namespace, `Tree.Position`, and traversal vocabulary that `Tree.Keyed` builds on
- `swift-buffer-arena-primitives` — the arena storage substrate used internally for node allocation and recycling
- `swift-dictionary-primitives` — the `Dictionary` namespace used for keyed child storage

---

## License

Apache License 2.0. See [LICENSE](LICENSE.md) for details.
