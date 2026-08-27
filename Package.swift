// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScribeCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ScribeCore", targets: ["ScribeCore"])
    ],
    dependencies: [
        // WhisperKit is added by the operator in Xcode once the App target exists —
        // see docs/XCODE_SETUP.md. Not pinned here to avoid resolving a package
        // dependency in an environment that cannot build/run it.
    ],
    targets: [
        .target(
            name: "ScribeCore",
            dependencies: []
        ),
        .testTarget(
            name: "ScribeCoreTests",
            dependencies: ["ScribeCore"]
        )
    ]
)
