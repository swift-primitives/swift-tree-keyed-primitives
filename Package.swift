// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-tree-keyed-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "Tree Keyed Primitives",
            targets: ["Tree Keyed Primitives"]
        ),
        .library(
            name: "Tree Keyed Primitives Test Support",
            targets: ["Tree Keyed Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-tree-primitives"),
        .package(path: "../swift-dictionary-primitives"),
        .package(path: "../swift-stack-primitives"),
        .package(path: "../swift-queue-primitives"),
        .package(path: "../swift-buffer-arena-primitives"),
    ],
    targets: [

        // MARK: - Tree Keyed (hash-indexed tree discipline; dictionary-backed)
        .target(
            name: "Tree Keyed Primitives",
            dependencies: [
                .product(name: "Tree Primitives Core", package: "swift-tree-primitives"),
                .product(name: "Dictionary Primitives", package: "swift-dictionary-primitives"),
                .product(name: "Stack Primitives", package: "swift-stack-primitives"),
                .product(name: "Queue Primitives Core", package: "swift-queue-primitives"),
                .product(name: "Queue Dynamic Primitives", package: "swift-queue-primitives"),
                .product(name: "Buffer Arena Primitives", package: "swift-buffer-arena-primitives"),
            ]
        ),

        // MARK: - Test Support ([MOD-024] spine)
        .target(
            name: "Tree Keyed Primitives Test Support",
            dependencies: [
                "Tree Keyed Primitives",
                .product(name: "Tree Primitives Test Support", package: "swift-tree-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Tree Keyed Primitives Tests",
            dependencies: [
                "Tree Keyed Primitives",
                "Tree Keyed Primitives Test Support",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
