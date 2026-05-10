import AppKit
import CoreGraphics
import Foundation

final class ReliabilityProbe {
    private var token: NSObjectProtocol?
    private var count = 0
    private var lastNotificationDate: Date?
    private let started = Date()
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func start() {
        print("Probe 5: Sequoia notification reliability stress test")
        print("Date: 2026-05-10T15:14:32.937-04:00")
        print("Run duration: 60 seconds")
        print("OS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        let frontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "<none>"
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        print("Initial frontmostApp=\(frontmostApp) pid=\(frontmostPID)")
        print("Initial windowCount=\(windowCount())")
        token = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] note in
            self?.handle(note)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(60))
        if let token { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        let elapsed = String(format: "%.3f", Date().timeIntervalSince(started))
        print("Finished. Notification count: \(count). Elapsed: \(elapsed)s")
    }

    private func handle(_ note: Notification) {
        let now = Date()
        count += 1
        let delta = lastNotificationDate.map { String(format: "%.3f", now.timeIntervalSince($0)) } ?? "n/a"
        let elapsed = String(format: "%.3f", now.timeIntervalSince(started))
        lastNotificationDate = now
        let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName ?? "<none>"
        print("notification #\(count) at \(formatter.string(from: now)) elapsed=\(elapsed)s delta=\(delta)s frontmost=\(frontmost) windowCount=\(windowCount()) userInfo=\(String(describing: note.userInfo))")
    }

    private func windowCount() -> Int {
        ((CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []).count
    }
}

ReliabilityProbe().start()
