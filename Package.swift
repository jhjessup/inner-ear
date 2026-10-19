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
        .library(name: "InnerEarRecording", targets: ["InnerEarRecording"]),
        .library(name: "InnerEarTranscription", targets: ["InnerEarTranscription"]),
        .library(name: "InnerEarTUIKit", targets: ["InnerEarTUIKit"])
    ],
    dependencies: [
        // Pinned exact, not `from:` — an open range let SwiftPM resolve to
        // whatever the latest compatible release is at checkout time, and
        // that release's bundled `GenerateManual` build plugin (man-page
        // generation we don't use) fails to compile under newer Swift
        // toolchains. SwiftPM compiles every plugin target in the
        // dependency graph while resolving it, regardless of whether any
        // target actually uses that plugin, so this blocked `swift build`
        // entirely before reaching our own code.
        //
        // Specifically: 1.8.0 refactored the plugin's shared code into
        // `Plugins/GenerateCommon`, switching to a newer `URL`/
        // `PluginContext` API that doesn't compile on some toolchains
        // (missing `import Foundation` for `URL`, plus a `pluginWorkDirectory`
        // vs. `pluginWorkDirectoryURL` mismatch). 1.7.2 — the latest patch
        // before that refactor — still uses the older `Path`-based API and
        // satisfies `argmax-oss-swift`'s floor requirement of
        // `swift-argument-parser` >= 1.7.0.
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.7.2"),
        // WhisperKit graduated into the Argmax Open-Source SDK at v1.0.0
        // (May 2026): same repo/product, now multi-product (WhisperKit +
        // SpeakerKit + TTSKit) instead of a single WhisperKit-only library.
        // Diarization (SpeakerKit) didn't exist as a product before 1.0.0,
        // hence the floor bump from the previous 0.9.0 pin. ONLY
        // `InnerEarTranscription` depends on this — see ARCHITECTURE.md for
        // why that boundary matters.
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0"),
    ],
    targets: [
        // The CLI front end / management engine: wires Recording,
        // Transcription, and the TUI together.
        .executableTarget(
            name: "InnerEarCLI",
            dependencies: [
                "InnerEarCore",
                "InnerEarRecording",
                "InnerEarTranscription",
                "InnerEarTUIKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        // Shared kernel: only genuinely cross-cutting code (data-directory
        // config resolution, the generic JSON-disk persistence helper).
        // Deliberately has NO domain models/services and NO WhisperKit/
        // SpeakerKit dependency — every other target depends on this one,
        // never the reverse.
        .target(
            name: "InnerEarCore"
        ),
        // Audio capture and the `Recording` model/store. No dependency on
        // WhisperKit/SpeakerKit/argmax-oss-swift at all, so recording-only
        // development, testing, and builds are never blocked by breakage
        // in the ML dependency chain (see ARCHITECTURE.md).
        .target(
            name: "InnerEarRecording",
            dependencies: ["InnerEarCore"]
        ),
        // Transcription/diarization/summarization/export. Depends on
        // InnerEarRecording for the `Recording` type (transcription acts on
        // a finished recording) and is the ONLY target that pulls in
        // WhisperKit/SpeakerKit.
        .target(
            name: "InnerEarTranscription",
            dependencies: [
                "InnerEarCore",
                "InnerEarRecording",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "SpeakerKit", package: "argmax-oss-swift"),
            ]
        ),
        .target(
            name: "InnerEarTUIKit",
            dependencies: ["InnerEarRecording", "InnerEarTranscription"]
        ),
        .testTarget(
            name: "InnerEarCoreTests",
            dependencies: ["InnerEarCore", "InnerEarRecording", "InnerEarTranscription"]
        ),
        .testTarget(
            name: "InnerEarTUIKitTests",
            dependencies: ["InnerEarTUIKit"]
        )
    ]
)
