import AppKit
import Darwin

final class OverlayController: NSObject {
    private var windows: [OverlayWindow] = []
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func start() {
        rebuildWindows()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        closeWindows()
    }

    @objc private func activeSpaceDidChange() {
        let timestamp = timestampFormatter.string(from: Date())
        print("[space-change] fired at \(timestamp)")
        fflush(stdout)
    }

    @objc private func screenParametersDidChange() {
        print("[screen-change] rebuilding overlay windows")
        fflush(stdout)
        rebuildWindows()
    }

    private func rebuildWindows() {
        closeWindows()

        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(screen: screen)
            let view = WatermarkView(frame: NSRect(origin: .zero, size: screen.visibleFrame.size))
            view.autoresizingMask = [.width, .height]
            window.contentView = view
            window.orderFrontRegardless()
            return window
        }
    }

    private func closeWindows() {
        windows.forEach { window in
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}
