// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Probe2WindowListScope",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Probe2WindowListScope", targets: ["Probe2WindowListScope"])],
    targets: [.executableTarget(name: "Probe2WindowListScope")]
)
