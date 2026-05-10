import AppKit
import CoreGraphics
import Foundation

func rect(from value: Any?) -> CGRect {
    guard let dict = value as? [String: Any], let rect = CGRect(dictionaryRepresentation: dict as CFDictionary) else { return .null }
    return rect
}

func bundleID(for window: [String: Any]) -> String {
    guard let pidNumber = window[kCGWindowOwnerPID as String] as? NSNumber else { return "<missing-pid>" }
    return NSRunningApplication(processIdentifier: pid_t(pidNumber.int32Value))?.bundleIdentifier ?? "<no-bundle-id>"
}

func describe(_ window: [String: Any]) -> String {
    let owner = (window[kCGWindowOwnerName as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "<unknown>"
    let title = (window[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "<untitled>"
    let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -999
    let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? -1
    let sharing = (window[kCGWindowSharingState as String] as? NSNumber)?.intValue ?? -999
    let store = (window[kCGWindowStoreType as String] as? NSNumber)?.intValue ?? -999
    let bounds = rect(from: window[kCGWindowBounds as String])
    return "bundle=\(bundleID(for: window)) owner=\"\(owner)\" title=\"\(title)\" layer=\(layer) alpha=\(alpha) sharing=\(sharing) store=\(store) bounds=\(bounds)"
}

let optionSets: [(String, CGWindowListOption)] = [
    ("onScreenOnly", [.optionOnScreenOnly]),
    ("all", [.optionAll]),
    ("onScreenOnlyExcludeDesktopElements", [.optionOnScreenOnly, .excludeDesktopElements])
]

print("Probe 4: minimized and hidden windows")
print("Date: 2026-05-10T15:14:32.937-04:00")
for (name, options) in optionSets {
    let windows = (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []
    let layerZero = windows.filter { (($0[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -999) == 0 }
    print("--- \(name) ---")
    print("count=\(windows.count) layer0Count=\(layerZero.count)")
    print("first 15 windows:")
    for (index, window) in windows.prefix(15).enumerated() {
        print("[\(index)] \(describe(window))")
    }
    print("first 15 layer-0 windows:")
    for (index, window) in layerZero.prefix(15).enumerated() {
        print("[layer0 \(index)] \(describe(window))")
    }
}
