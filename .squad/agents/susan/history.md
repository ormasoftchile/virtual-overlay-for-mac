# Susan — History

## Project Context
- **Project:** virtual-overlay-for-mac
- **User:** ormasoftchile (Cristian)
- **Created:** 2026-05-10
- **Stack:** Swift, SwiftUI + AppKit, macOS native
- **Goal:** Persistent ambient watermark identifying the current macOS Space.

## Design Philosophy (inherited from product brief)
- **Restrained, elegant, minimal, operationally useful.** Like Bloomberg terminal labels or architectural signage.
- **NOT flashy, gamer-like, RGB/neon, widget-looking, or cluttered.**
- Watermark in-app: text-only, SF Pro / SF Mono, thin/medium weight, large letter spacing, ~5–12% opacity.
- The icon should feel like it belongs to the same family.

## Working with
- App is bundled at `dist/Virtual Overlay.app` via `bundle.sh`
- Icon goes into `Contents/Resources/AppIcon.icns`
- bundle.sh needs an update to reference it
- Generator script lives at `Tools/IconGenerator/`

## Learnings
_(append below as work proceeds)_

- **2026-05-10T17:26:50.686-04:00 — App icon:** Chose a restrained typographic `[V]`-like mark: an SF Pro ultra-light `V` framed by drawn bracket rules on a near-black squircle. At 16×16 the refined ultra-light type softens, but the centered V plus bracket stems preserve the infrastructural signage read. Source-of-truth generator lives at `Tools/IconGenerator/`; generated outputs are checked in at `Resources/AppIcon.iconset/` and `Resources/AppIcon.icns`. Bundle wiring copies the icns to `dist/Virtual Overlay.app/Contents/Resources/AppIcon.icns` and declares `CFBundleIconFile = AppIcon`.
