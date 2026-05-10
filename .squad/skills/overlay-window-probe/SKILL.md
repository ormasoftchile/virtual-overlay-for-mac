---
name: "overlay-window-probe"
description: "Public-AppKit pattern for a transparent, click-through macOS watermark overlay on every display"
domain: "macos-appkit"
confidence: "medium"
source: "ken-overlay-window-probe-2026-05-10"
---

## Context

Use this pattern when building or probing a lightweight macOS overlay that should appear above normal windows, on all Spaces, without intercepting mouse clicks.

## Pattern

1. Create one borderless `NSWindow` per `NSScreen`.
2. Size each window to `screen.visibleFrame` for menu/Dock-safe coverage, or `screen.frame` if full physical display coverage is required.
3. Configure the window:
   - `level = .floating`
   - `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`
   - `ignoresMouseEvents = true`
   - `isOpaque = false`
   - `backgroundColor = .clear`
   - `hasShadow = false`
4. Render watermark content in a simple `NSView` or SwiftUI view hosted inside the window.
5. Observe `NSWorkspace.activeSpaceDidChangeNotification` for public Space-change signal only; do not expect a stable Space ID from it.
6. Observe `NSApplication.didChangeScreenParametersNotification` and rebuild per-screen windows.

## Why

- `.floating` is documented and avoids reserved system levels.
- `.canJoinAllSpaces` gives broad Space visibility.
- `.fullScreenAuxiliary` is the public AppKit path for fullscreen app compatibility.
- `ignoresMouseEvents` gives whole-window click-through without Accessibility or Input Monitoring permissions.

## Caveats

- This does not identify the active Space.
- Fullscreen and Stage Manager behavior must be verified on real machines.
- Window-level click-through is all-or-nothing; selective interactions require a different event-routing design.
- Public AppKit only: do not add CGS/SkyLight/private symbols to this v1 pattern.
