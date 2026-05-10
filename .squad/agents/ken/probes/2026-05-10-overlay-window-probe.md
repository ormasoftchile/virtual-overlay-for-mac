# Overlay Window Probe

**Date:** 2026-05-10T11:57:23.673-04:00  
**Owner:** Ken  
**Scope:** M1 faded watermark on every screen, public AppKit APIs only

## What I built

Created a standalone SwiftPM prototype at:

- `Prototypes/OverlayWindowProbe/Package.swift`
- `Prototypes/OverlayWindowProbe/Sources/OverlayWindowProbe/OverlayWindow.swift`
- `Prototypes/OverlayWindowProbe/Sources/OverlayWindowProbe/WatermarkView.swift`
- `Prototypes/OverlayWindowProbe/Sources/OverlayWindowProbe/OverlayController.swift`
- `Prototypes/OverlayWindowProbe/Sources/OverlayWindowProbe/main.swift`
- `Prototypes/OverlayWindowProbe/README.md`

The prototype creates one transparent, borderless, click-through `NSWindow` per `NSScreen`, renders a large faded `PROTOTYPE` watermark in the lower-right, observes public Space-change notifications, and rebuilds windows on display changes.

## Build command and observed result

Command run from `Prototypes/OverlayWindowProbe`:

```bash
swift build
```

Observed result on this machine: **blocked by local Command Line Tools / SDK mismatch before source compilation.** SwiftPM failed while linking the generated package manifest with `Undefined symbols for architecture arm64` involving `PackageDescription.Package.__allocating_init(...)`. Retrying with alternate Swift tools versions exposed the same local toolchain issue as an SDK/compiler mismatch. This is not an overlay-source error; SwiftPM did not reach the prototype target.

## Alan recipe adjustments

- Used `screen.visibleFrame` for the window content rect because the request explicitly asked for the screen's full visible frame. This avoids menu bar / Dock reserved areas in the prototype.
- Used `.floating` exactly as Alan recommended. I did not test `.statusBar` or `.screenSaver` because v1 is public-API-only and those levels are system-reserved/riskier.
- Used a custom `NSView` (`WatermarkView`) instead of SwiftUI/`NSHostingView` to keep the probe tiny and avoid any app-bundle or lifecycle gymnastics.
- Added explicit stdout flushing after notification logs so Terminal users see Space-change events immediately.

## Open behavioral questions for real-Mac testing

1. Does `.floating + .fullScreenAuxiliary` keep the watermark above Safari/Chrome/Xcode fullscreen Spaces on the target macOS versions?
2. Does `NSWorkspace.activeSpaceDidChangeNotification` fire once or multiple times per gesture across trackpad swipes, Mission Control, and keyboard Space switching?
3. Does `screen.visibleFrame` leave too much uncovered area for the product goal, especially on displays with hidden Dock or menu bar? If yes, switch the real module to `screen.frame`.
4. Does the watermark appear on all displays when displays have separate Spaces enabled and disabled?
5. Does Stage Manager reorder or temporarily hide `.floating` auxiliary windows?

## What Cristian should look for when running

Run:

```bash
cd Prototypes/OverlayWindowProbe
swift run
```

Expected behavior:

- A pale, large `PROTOTYPE` watermark appears in the lower-right of every connected display.
- Normal clicks pass through the watermark to underlying apps.
- Switching Spaces prints lines like `[space-change] fired at 2026-05-10T11:57:23Z` in Terminal.
- Adding/removing/changing displays prints `[screen-change] rebuilding overlay windows` and recreates one overlay per screen.
- Cmd-Q quits cleanly from the app menu.
