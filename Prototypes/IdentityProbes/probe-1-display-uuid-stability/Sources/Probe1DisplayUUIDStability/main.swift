import AppKit
import CoreGraphics
import Foundation

func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
    return CGDirectDisplayID(number.uint32Value)
}

func uuidString(for displayID: CGDirectDisplayID) -> String {
    guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(displayID) else { return "<nil>" }
    let uuid = unmanagedUUID.takeRetainedValue()
    return CFUUIDCreateString(kCFAllocatorDefault, uuid) as String
}

print("Probe 1: display UUID stability")
print("Date: 2026-05-10T15:14:32.937-04:00")
print("Screen count: \(NSScreen.screens.count)")
for (index, screen) in NSScreen.screens.enumerated() {
    if let id = displayID(for: screen) {
        print("screen[\(index)] name=\"\(screen.localizedName)\" displayID=\(id) uuid=\(uuidString(for: id)) frame=\(screen.frame) visibleFrame=\(screen.visibleFrame)")
    } else {
        print("screen[\(index)] name=\"\(screen.localizedName)\" displayID=<missing> uuid=<unavailable> frame=\(screen.frame) visibleFrame=\(screen.visibleFrame)")
    }
}
