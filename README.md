# Virtual Overlay for Mac

## What it is

Virtual Overlay is a persistent ambient watermark for macOS Spaces. It identifies which Space you're on without Dock noise, built for power users, presenters, and multi-monitor setups.

## Requirements

- macOS 13+
- Apple Silicon and Intel Macs are both supported by the Swift code. The local release builder emits the host Mac architecture; `bundle.sh` does not produce a universal binary yet.

## Install

1. Download `Virtual-Overlay-vX.Y.Z.zip` from the [latest release](https://github.com/ormasoftchile/virtual-overlay-for-mac/releases/latest).
2. Unzip and drag `Virtual Overlay.app` to `/Applications`.
3. Open Terminal and run:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Virtual Overlay.app"
   open "/Applications/Virtual Overlay.app"
   ```
4. After that, double-click launches normally.

### Why the extra step?

Virtual Overlay uses private CoreGraphics / SkyLight APIs (`CGSManagedDisplayGetCurrentSpace`) for accurate per-display Space detection. Apple's notarization service rejects apps that link these symbols, so the binary is ad-hoc signed instead of Developer-ID signed. macOS adds a `com.apple.quarantine` flag to anything downloaded from the internet; the `xattr -dr` command above removes that flag for this one app, so macOS will trust the local ad-hoc signature.

This is the same constraint [Yabai](https://github.com/koekeishiya/yabai) works under — common practice for macOS tools that need private APIs.

If you'd rather not run that command, build from source — see [Building](#building) below.

## Optional verification

```bash
shasum -a 256 Virtual-Overlay-vX.Y.Z.zip
```

The SHA-256 output should match the `.sha256` file on the release page.

## Usage

Launch the app and the watermark appears on your Spaces. Cmd-, opens Preferences for color, opacity, font family, font size, and position. Option-click the watermark to rename the current Space. The status bar menu includes Quit and Rename. Virtual Overlay is a status bar app; it has no Dock icon.

## Add to Login Items

System Settings → General → Login Items → +, then select `/Applications/Virtual Overlay.app`.

## Building

```bash
git clone https://github.com/ormasoftchile/virtual-overlay-for-mac.git
cd virtual-overlay-for-mac
swift build -c release
./bundle.sh
```

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
