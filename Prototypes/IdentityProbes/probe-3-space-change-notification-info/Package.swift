// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Probe3SpaceChangeNotificationInfo",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Probe3SpaceChangeNotificationInfo", targets: ["Probe3SpaceChangeNotificationInfo"])],
    targets: [.executableTarget(name: "Probe3SpaceChangeNotificationInfo")]
)
