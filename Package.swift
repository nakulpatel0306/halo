// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Halo",
    platforms: [.macOS(.v14)],
    targets: [
        // Everything that doesn't need a running app: settings model, the action
        // catalog, file operations, ring geometry and the Claude client.
        .target(name: "HaloKit"),
        .testTarget(name: "HaloKitTests", dependencies: ["HaloKit"]),
    ],
    swiftLanguageModes: [.v5]
)
