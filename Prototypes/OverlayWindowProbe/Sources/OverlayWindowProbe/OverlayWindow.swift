import AppKit

final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        let frame = screen.visibleFrame

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        // .floating sits above normal app windows without using system-reserved
        // levels like .statusBar or .screenSaver, keeping this prototype on the
        // public/notarization-safe AppKit path.
        level = .floating

        // canJoinAllSpaces: replicate the overlay into every desktop Space.
        // stationary: avoid sliding with Space transition animations.
        // fullScreenAuxiliary: allow the overlay alongside fullscreen apps.
        // ignoresCycle: keep the overlay out of this app's Cmd-` window cycle.
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        // Whole-window click-through: mouse events pass to apps underneath.
        // This does not make selective controls clickable; that needs a future
        // view-level/event-routing design.
        ignoresMouseEvents = true

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
