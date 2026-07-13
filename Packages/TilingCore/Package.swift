// swift-tools-version:6.0
// SPDX-License-Identifier: GPL-3.0-only
import PackageDescription

let package = Package(
    name: "TilingCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TilingCore", targets: ["TilingCore"])
    ],
    targets: [
        .target(name: "TilingCore"),
        .testTarget(
            name: "TilingCoreTests",
            dependencies: ["TilingCore"]
        )
    ]
)
