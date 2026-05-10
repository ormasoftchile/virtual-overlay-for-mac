# Virtual Overlay for Mac

Virtual Overlay is a public-API-only macOS agent that draws a persistent, click-through watermark over every Space so users can see and eventually rename their current desktop context without Dock or window-manager noise.

## Build

```bash
swift build
```

## Run

```bash
swift run VirtualOverlay
```

## Modules

- `App` — thin `NSApplication` shell that wires modules together and owns LSUIElement app launch behavior.
- `OverlayRenderer` — transparent `NSWindow` instances plus SwiftUI watermark rendering.
- `SpaceDetection` — public `NSWorkspace.activeSpaceDidChangeNotification` strategy and heuristic Space identity types.
- `Persistence` — JSON-backed `SpaceIdentity → name` store at `~/Library/Application Support/VirtualOverlay/spaces.json`.
- `Interaction` — M1 rename-request surface with Option-click capture stubbed for M2.

## Toolchain note

This scaffold is SwiftPM-only for v1 development and requires a matched Xcode / Command Line Tools installation. On this machine, Ken previously observed a Command Line Tools mismatch where SwiftPM failed while linking the `PackageDescription` manifest before compiling sources.

## Prototype history

Ken's original public-AppKit probe remains intact at [`Prototypes/OverlayWindowProbe/`](Prototypes/OverlayWindowProbe/) as historical reference.
