// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InnerEar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "innerear", targets: ["InnerEarCLI"]),
        .library(name: "InnerEarCore", targets: ["InnerEarCore"]),
        .library(name: "InnerEarTUIKit", targets: ["InnerEarTUIKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        // First target: the CLI front end to the core engine.
        .executableTarget(
            name: "InnerEarCLI",
            dependencies: [
                "InnerEarCore",
                "InnerEarTUIKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "InnerEarCore",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
            ]
        ),
        .target(
            name: "InnerEarTUIKit",
            dependencies: ["InnerEarCore"]
        ),
        .testTarget(
            name: "InnerEarCoreTests",
            dependencies: ["InnerEarCore"]
        ),
        .testTarget(
            name: "InnerEarTUIKitTests",
            dependencies: ["InnerEarTUIKit"]
        )
    ]
)