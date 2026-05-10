// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Probe5SequoiaNotificationReliability",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Probe5SequoiaNotificationReliability", targets: ["Probe5SequoiaNotificationReliability"])],
    targets: [.executableTarget(name: "Probe5SequoiaNotificationReliability")]
)
