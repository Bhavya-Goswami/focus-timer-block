// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FocusOverlay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FocusOverlay", targets: ["FocusOverlay"])
    ],
    targets: [
        .executableTarget(
            name: "FocusOverlay",
            path: "Sources/FocusOverlay",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
