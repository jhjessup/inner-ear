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
        // WhisperKit graduated into the Argmax Open-Source SDK at v1.0.0
        // (May 2026): same repo/package, now multi-product (WhisperKit +
        // SpeakerKit + TTSKit) instead of a single WhisperKit-only library.
        // Diarization (SpeakerKit) didn't exist as a product before 1.0.0,
        // hence the floor bump from the previous 0.9.0 pin.
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0"),
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
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "SpeakerKit", package: "argmax-oss-swift"),
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