// App — thin NSApplication shell that wires Virtual Overlay modules together.

import AppKit
import Combine
import Interaction
import OverlayRenderer
import Persistence
import SpaceDetection

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferencesStore = JSONFilePreferencesStore()
    private lazy var watermarkAppearance = WatermarkAppearance(preferences: preferencesStore.preferences())
    private lazy var overlayController = OverlayController(watermarkAppearance: watermarkAppearance)
    private let spaceFingerprinter = SpaceFingerprinter()
    private lazy var spaceDetector = NSWorkspaceSpaceDetector(snapshotProvider: { [spaceFingerprinter] in
        spaceFingerprinter.currentSnapshots()
    })
    private let nameStore = JSONFileSpaceNameStore()
    private lazy var preferencesWindowController = PreferencesWindowController(appearance: watermarkAppearance)
    private var renameController: OptionClickRenameController?
    private var statusItem: NSStatusItem?
    private var spaceTask: Task<Void, Never>?
    private var preferencesCancellable: AnyCancellable?
    private var preferencesSaveTask: Task<Void, Never>?
    private var currentIdentity: SpaceIdentity?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        configureRenameController()
        configurePreferencesPersistence()
        configureStatusItem()
        overlayController.start()
        renameController?.start()
        spaceDetector.startObserving()

        spaceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshFromCurrentSpace()
            for await event in self.spaceDetector.changes {
                self.apply(snapshots: event.snapshots)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        spaceTask?.cancel()
        preferencesSaveTask?.cancel()
        preferencesStore.save(watermarkAppearance.preferences)
        spaceDetector.stopObserving()
        renameController?.stop()
        overlayController.stop()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences(_:)), keyEquivalent: ",")
        preferencesItem.target = self
        appMenu.addItem(preferencesItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Virtual Overlay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func configureRenameController() {
        renameController = OptionClickRenameController(
            overlayController: overlayController,
            nameStore: nameStore,
            currentIdentity: { [weak self] in self?.spaceFingerprinter.currentIdentity() },
            refreshDisplayName: { [weak self] in self?.refreshDisplayNameFromFreshIdentity() }
        )
    }

    private func configurePreferencesPersistence() {
        preferencesCancellable = watermarkAppearance.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.schedulePreferencesSave()
            }
        }
    }

    private func schedulePreferencesSave() {
        preferencesSaveTask?.cancel()
        preferencesSaveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                return
            }
            guard let self else { return }
            self.preferencesStore.save(self.watermarkAppearance.preferences)
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "Virtual Overlay")

        let menu = NSMenu()
        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences(_:)), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        let renameItem = NSMenuItem(title: "Rename current Space…", action: #selector(renameCurrentSpace(_:)), keyEquivalent: "r")
        renameItem.target = self
        menu.addItem(renameItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Virtual Overlay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func openPreferences(_ sender: Any?) {
        preferencesWindowController.showPreferences()
    }

    @objc private func renameCurrentSpace(_ sender: Any?) {
        renameController?.beginRenameProgrammatically()
    }

    private func refreshFromCurrentSpace() async {
        do {
            apply(snapshots: try await spaceDetector.detect())
        } catch {
            currentIdentity = nil
            overlayController.updateText("UNNAMED")
        }
    }

    private func apply(snapshots: [SpaceSnapshot]) {
        guard let identity = snapshots.first?.identity else {
            currentIdentity = nil
            overlayController.updateText("UNNAMED")
            return
        }
        currentIdentity = identity
        refreshDisplayNameFromCurrentIdentity()
    }

    private func refreshDisplayNameFromCurrentIdentity() {
        displayName(for: currentIdentity)
    }

    private func refreshDisplayNameFromFreshIdentity() {
        currentIdentity = spaceFingerprinter.currentIdentity()
        displayName(for: currentIdentity)
    }

    private func displayName(for identity: SpaceIdentity?) {
        guard let identity else {
            overlayController.updateText("UNNAMED")
            return
        }
        let matchedIdentity = nameStore.match(currentFingerprint: identity)
        let text = matchedIdentity.flatMap { nameStore.name(for: $0) } ?? "UNNAMED"
        overlayController.updateText(text)
    }
}

private let application = NSApplication.shared
// SwiftPM executable targets cannot carry a top-level Info.plist resource;
// set accessory activation in code to get LSUIElement-style behavior.
application.setActivationPolicy(.accessory)
private let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
application.run()
