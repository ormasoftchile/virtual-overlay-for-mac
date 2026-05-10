// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Probe4MinimizedAndHiddenWindows",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Probe4MinimizedAndHiddenWindows", targets: ["Probe4MinimizedAndHiddenWindows"])],
    targets: [.executableTarget(name: "Probe4MinimizedAndHiddenWindows")]
)
