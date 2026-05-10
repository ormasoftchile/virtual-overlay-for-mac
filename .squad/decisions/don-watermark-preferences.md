# Don Decision: Watermark Preferences v1

**Date:** 2026-05-10T19:06:07.182-04:00  
**From:** Don  
**Status:** Proposed

## Preferences schema v1

Watermark appearance preferences live in a dedicated JSON file:

`~/Library/Application Support/VirtualOverlay/preferences.json`

Shape:

```swift
struct WatermarkPreferences: Codable {
    var color: CodableColor
    var fontSize: CGFloat
    var position: WatermarkPosition
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}
```

Defaults preserve the pre-preferences hardcoding: white sRGB RGBA `(1, 1, 1, 0.10)`, `fontSize = 240`, `position = .lowerRight`.

`preferences.json` is intentionally independent from `spaces.json`; appearance schema migration and Space-name identity migration have different risks and timelines.

## Live preview pattern

Preferences are edited through one shared `WatermarkAppearance` observable. The Preferences window writes into that object; `OverlayController` subscribes to the same object and re-renders immediately. There is no Apply button.

Disk writes are debounced at 500ms after the last change, then flushed on app termination. This keeps slider drags responsive and avoids JSON write thrash while preserving native macOS live-preview behavior.
