import AppKit
import CoreGraphics
import Foundation

final class SpaceChangeProbe {
    private var token: NSObjectProtocol?
    private var count = 0
    private let started = Date()
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func start() {
        print("Probe 3: activeSpaceDidChangeNotification info")
        print("Date: 2026-05-10T15:14:32.937-04:00")
        print("Run duration: 60 seconds")
        print("Initial snapshot:")
        snapshot(prefix: "initial")
        token = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] note in
            self?.handle(note)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(60))
        if let token { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        let elapsed = String(format: "%.3f", Date().timeIntervalSince(started))
        print("Finished. Notification count: \(count). Elapsed: \(elapsed)s")
    }

    private func handle(_ note: Notification) {
        count += 1
        let now = Date()
        let elapsed = String(format: "%.3f", now.timeIntervalSince(started))
        print("--- notification #\(count) at \(formatter.string(from: now)) elapsed=\(elapsed)s ---")
        print("name=\(note.name.rawValue) object=\(String(describing: note.object)) userInfo=\(String(describing: note.userInfo))")
        snapshot(prefix: "after-notification-\(count)")
    }

    private func snapshot(prefix: String) {
        let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
        print("\(prefix): windowCount=\(windows.count)")
        for (index, window) in windows.prefix(20).enumerated() {
            let owner = (window[kCGWindowOwnerName as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "<unknown>"
            let title = (window[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "<untitled>"
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -999
            print("\(prefix)[\(index)] owner=\"\(owner)\" title=\"\(title)\" layer=\(layer)")
        }
    }
}

SpaceChangeProbe().start()
