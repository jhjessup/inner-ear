// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InnerEar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "innerear", targets: ["InnerEarCLI"]),
        .library(name: "InnerEarCore", targets: ["InnerEarCore"])
    ],
    dependencies: [
        // WhisperKit is added by the operator in Xcode once the GUI App target
        // exists — see docs/XCODE_SETUP.md. Not pinned here to avoid resolving
        // a package dependency in an environment that cannot build/run it.
    ],
    targets: [
        // First target: the CLI front end to the core engine.
        .executableTarget(
            name: "InnerEarCLI",
            dependencies: ["InnerEarCore"]
        ),
        .target(
            name: "InnerEarCore",
            dependencies: []
        ),
        .testTarget(
            name: "InnerEarCoreTests",
            dependencies: ["InnerEarCore"]
        )
    ]
)
