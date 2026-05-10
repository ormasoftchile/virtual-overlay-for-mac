// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VirtualOverlay",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "OverlayRenderer", targets: ["OverlayRenderer"]),
        .library(name: "SpaceDetection", targets: ["SpaceDetection"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "Interaction", targets: ["Interaction"]),
        .executable(name: "VirtualOverlay", targets: ["App"])
    ],
    targets: [
        .target(name: "OverlayRenderer"),
        .target(name: "SpaceDetection"),
        .target(name: "Persistence", dependencies: ["SpaceDetection"]),
        .target(name: "Interaction", dependencies: ["OverlayRenderer", "Persistence", "SpaceDetection"]),
        .executableTarget(
            name: "App",
            dependencies: ["OverlayRenderer", "SpaceDetection", "Persistence", "Interaction"]
        ),
        .testTarget(name: "OverlayRendererTests", dependencies: ["OverlayRenderer"]),
        .testTarget(name: "SpaceDetectionTests", dependencies: ["SpaceDetection"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "SpaceDetection"]),
        .testTarget(name: "InteractionTests", dependencies: ["Interaction", "OverlayRenderer", "Persistence", "SpaceDetection"])
    ]
)
