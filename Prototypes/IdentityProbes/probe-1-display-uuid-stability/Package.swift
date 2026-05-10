// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Probe1DisplayUUIDStability",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Probe1DisplayUUIDStability", targets: ["Probe1DisplayUUIDStability"])],
    targets: [.executableTarget(name: "Probe1DisplayUUIDStability")]
)
