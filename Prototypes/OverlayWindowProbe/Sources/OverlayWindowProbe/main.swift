import AppKit

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlayController = OverlayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        overlayController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlayController.stop()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        appMenu.addItem(
            NSMenuItem(
                title: "Quit OverlayWindowProbe",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
