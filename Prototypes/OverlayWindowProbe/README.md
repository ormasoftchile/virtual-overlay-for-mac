# OverlayWindowProbe

**Date:** 2026-05-10T11:57:23.673-04:00

Minimal SwiftPM/AppKit probe for M1: draw a faded `PROTOTYPE` watermark on every connected display using only public AppKit APIs.

## Build

```bash
cd Prototypes/OverlayWindowProbe
swift build
```

Observed result on 2026-05-10T11:57:23.673-04:00: attempted locally, but this machine's Command Line Tools are mismatched. SwiftPM failed before compiling the prototype sources while linking the package manifest (`Undefined symbols for architecture arm64` in `PackageDescription`). Run this command again on a normal matched Xcode/CLT install.

## Run

```bash
cd Prototypes/OverlayWindowProbe
swift run
```

Quit with **Cmd-Q** from the app menu. When run from Terminal, the process stays alive in the `NSApplication` run loop.

## macOS-specific behavior

- One borderless `NSWindow` is created per `NSScreen`, sized to `screen.visibleFrame` so the prototype avoids the menu bar and Dock reserved areas.
- `level = .floating` keeps the watermark above normal app windows without using system-reserved levels such as `.statusBar` or `.screenSaver`, which are riskier for distribution and user trust.
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]` follows Alan's recipe: all Spaces, stable during Space animations, eligible to appear alongside fullscreen apps, and skipped by Cmd-` window cycling.
- `ignoresMouseEvents = true` makes the whole overlay click-through. This is all-or-nothing at the window level; selective clickable controls are intentionally deferred.
- The prototype observes `NSWorkspace.activeSpaceDidChangeNotification` and prints `[space-change] fired at <UTC timestamp>` for each public Space-change notification. It does not try to identify or name the Space.
- The prototype observes `NSApplication.didChangeScreenParametersNotification` and rebuilds all overlay windows after display add/remove or geometry changes.

## Deferred

No private CGS/SkyLight APIs, persistence, naming, icons, gradients, animations, custom Info.plist, or LSUIElement agent behavior are included in this probe.
