// swift-tools-version:6.0
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
