# Virtual Overlay for Mac

## What it is

Virtual Overlay is a persistent ambient watermark for macOS Spaces. It identifies which Space you're on without Dock noise, built for power users, presenters, and multi-monitor setups.

## Requirements

- macOS 13+
- Apple Silicon and Intel Macs are both supported by the Swift code. The local release builder emits the host Mac architecture; `bundle.sh` does not produce a universal binary yet.

## Install

1. Download `Virtual-Overlay-vX.Y.Z.zip` from the latest GitHub Release.
2. Unzip it, then drag `Virtual Overlay.app` to `/Applications`.
3. **First launch:** right-click `Virtual Overlay.app` → Open → Open. macOS shows an “unidentified developer” warning because the app uses private SkyLight APIs and cannot be notarized. This is expected. The right-click→Open dance bypasses Gatekeeper for trusted local apps. After the first launch, double-click works normally.

## Optional verification

```bash
shasum -a 256 Virtual-Overlay-vX.Y.Z.zip
```

The SHA-256 output should match the `.sha256` file on the release page.

## Usage

Launch the app and the watermark appears on your Spaces. Cmd-, opens Preferences for color, opacity, font family, font size, and position. Option-click the watermark to rename the current Space. The status bar menu includes Quit and Rename. Virtual Overlay is a status bar app; it has no Dock icon.

## Add to Login Items

System Settings → General → Login Items → +, then select `/Applications/Virtual Overlay.app`.

## Why it can't be notarized

Virtual Overlay uses private CoreGraphics / SkyLight APIs (`CGSManagedDisplayGetCurrentSpace`) to detect the active Space per display. Apple's notarization service rejects apps that link to private symbols; this is the same constraint Yabai works under. The app is open source — build from source if you don't trust the binary.

## Development

```bash
swift run
./bundle.sh
```

The bundle uses `com.ormasoftchile.virtualoverlay` as its local bundle identifier. The release ZIP is built locally with `./ship.sh VERSION`.

The app icon is generated programmatically. To modify it, edit the Swift generator in `Tools/IconGenerator/`, run `swift run` from that directory, then rebuild `Resources/AppIcon.icns` with `iconutil`.

## Modules

- `App` — thin `NSApplication` shell that wires modules together and owns LSUIElement app launch behavior.
- `OverlayRenderer` — transparent `NSWindow` instances plus SwiftUI watermark rendering.
- `SpaceDetection` — `NSWorkspace.activeSpaceDidChangeNotification` plus private CGS/SkyLight Space identity when available.
- `Persistence` — JSON-backed `SpaceIdentity → name` store at `~/Library/Application Support/VirtualOverlay/spaces.json`.
- `Interaction` — Option-click rename, Preferences, and status bar menu wiring.

## Toolchain note

This scaffold is SwiftPM-only for v1 development and requires a matched Xcode / Command Line Tools installation. On this machine, Ken previously observed a Command Line Tools mismatch where SwiftPM failed while linking the `PackageDescription` manifest before compiling sources.

## Prototype history

Ken's original public-AppKit probe remains intact at [`Prototypes/OverlayWindowProbe/`](Prototypes/OverlayWindowProbe/) as historical reference.
