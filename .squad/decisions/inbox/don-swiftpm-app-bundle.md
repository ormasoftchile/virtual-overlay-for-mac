# Don Decision: SwiftPM App Bundle Script

**Date:** 2026-05-10T17:02:16.335-04:00  
**From:** Don  
**Status:** Implemented

## Decision

Keep the project SwiftPM-only and add a root `bundle.sh` script that wraps the release SwiftPM product into `dist/Virtual Overlay.app`.

## Choices

- Bundle identifier: `com.ormasoftchile.virtualoverlay`.
- Product source: `swift build -c release --product VirtualOverlay`, copied from `.build/release/VirtualOverlay`.
- Bundle executable name: `Virtual Overlay`, matching `CFBundleExecutable`.
- Version scheme: script-local `CFBundleShortVersionString = 0.1.0` and `CFBundleVersion = 1` for v1.
- Minimum macOS: `13.0`, matching `Package.swift`'s `.macOS(.v13)`.
- Launch Services behavior: include `LSUIElement = true` in `Info.plist` while keeping the runtime accessory activation policy.
- Signing: ad-hoc local signing only via `codesign --force --deep --sign -`; failures warn but do not fail the bundle build.

## Non-goals

No Xcode project, notarization, DMG, Sparkle auto-update, app icon, or certificate setup in this step.
