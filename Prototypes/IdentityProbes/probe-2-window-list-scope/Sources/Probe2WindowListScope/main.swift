import AppKit
import CoreGraphics
import Foundation

struct DisplayInfo {
    let id: CGDirectDisplayID
    let name: String
    let bounds: CGRect
}

func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
    return CGDirectDisplayID(number.uint32Value)
}

func displays() -> [DisplayInfo] {
    NSScreen.screens.compactMap { screen in
        guard let id = displayID(for: screen) else { return nil }
        return DisplayInfo(id: id, name: screen.localizedName, bounds: CGDisplayBounds(id))
    }
}

func rect(from value: Any?) -> CGRect {
    guard let dict = value as? [String: Any], let rect = CGRect(dictionaryRepresentation: dict as CFDictionary) else { return .null }
    return rect
}

func bundleID(for pidNumber: NSNumber?) -> String {
    guard let pidNumber else { return "<missing-pid>" }
    let pid = pid_t(pidNumber.int32Value)
    return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "<no-bundle-id>"
}

func clean(_ value: Any?) -> String {
    let string = (value as? String) ?? ""
    return string.isEmpty ? "<untitled>" : string.replacingOccurrences(of: "\n", with: " ")
}

let displayInfos = displays()
let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []

let displayText = displayInfos.map { "\($0.name)(id=\($0.id), bounds=\($0.bounds))" }.joined(separator: "; ")
print("Probe 2: window list scope")
print("Date: 2026-05-10T15:14:32.937-04:00")
print("Displays: \(displayText)")
print("Window count (.optionOnScreenOnly): \(windows.count)")

for (index, window) in windows.enumerated() {
    let owner = clean(window[kCGWindowOwnerName as String])
    let title = clean(window[kCGWindowName as String])
    let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -999
    let pid = window[kCGWindowOwnerPID as String] as? NSNumber
    let bounds = rect(from: window[kCGWindowBounds as String])
    let hitDisplays = displayInfos.filter { !$0.bounds.intersection(bounds).isNull && !$0.bounds.intersection(bounds).isEmpty }
    let hitText = hitDisplays.isEmpty ? "<none>" : hitDisplays.map { "\($0.name)(\($0.id))" }.joined(separator: ",")
    print("[\(index)] bundle=\(bundleID(for: pid)) owner=\"\(owner)\" title=\"\(title)\" layer=\(layer) bounds=\(bounds) screens=\(hitText)")
}
