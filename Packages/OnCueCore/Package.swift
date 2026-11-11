// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OnCueCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OnCueCore", targets: ["OnCueCore"]),
    ],
    targets: [
        // Show model, persistence, machine profile and device integrations.
        // No UI code and no external dependencies.
        .target(name: "OnCueCore"),
        .testTarget(
            name: "OnCueCoreTests",
            dependencies: ["OnCueCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
