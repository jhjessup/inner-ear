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
        // Pinned exact, not `from:` — an open range let SwiftPM resolve to
        // whatever the latest compatible release is at checkout time, and a
        // newer release's bundled `GenerateManual` build plugin (man-page
        // generation we don't use) fails to compile under newer Swift
        // toolchains (missing `import Foundation` for `URL`, plus a
        // `PluginContext` API mismatch) — SwiftPM compiles every plugin
        // target in the dependency graph while resolving it, regardless of
        // whether any target actually uses that plugin, so this blocked
        // `swift build` entirely before reaching our own code. Pinning to
        // 1.3.0 (the version this project has always targeted) avoids
        // whichever newer release carries the broken plugin.
        .package(url: "https://github.com/apple/swift-argument-parser.git", .exact("1.3.0")),
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