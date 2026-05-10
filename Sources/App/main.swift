// App — thin NSApplication shell that wires Virtual Overlay modules together.

import AppKit
import Interaction
import OverlayRenderer
import Persistence
import SpaceDetection

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlayController = OverlayController()
    private let spaceFingerprinter = SpaceFingerprinter()
    private lazy var spaceDetector = NSWorkspaceSpaceDetector(snapshotProvider: { [spaceFingerprinter] in
        spaceFingerprinter.currentSnapshots()
    })
    private let nameStore = JSONFileSpaceNameStore()
    private var renameController: OptionClickRenameController?
    private var statusItem: NSStatusItem?
    private var spaceTask: Task<Void, Never>?
    private var currentIdentity: SpaceIdentity?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureRenameController()
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
        spaceDetector.stopObserving()
        renameController?.stop()
        overlayController.stop()
    }

    private func configureRenameController() {
        renameController = OptionClickRenameController(
            overlayController: overlayController,
            nameStore: nameStore,
            currentIdentity: { [weak self] in self?.spaceFingerprinter.currentIdentity() },
            refreshDisplayName: { [weak self] in self?.refreshDisplayNameFromFreshIdentity() }
        )
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "Virtual Overlay")

        let menu = NSMenu()
        let renameItem = NSMenuItem(title: "Rename current Space…", action: #selector(renameCurrentSpace(_:)), keyEquivalent: "r")
        renameItem.target = self
        menu.addItem(renameItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Virtual Overlay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
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
