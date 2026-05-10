# LSUIElement via setActivationPolicy

**Captured:** 2026-05-10T15:14:32.937-04:00

## Pattern

For a SwiftPM macOS executable target that needs background/accessory app behavior, do not add `Info.plist` as a target resource. SwiftPM forbids top-level `Info.plist` resources in executable targets.

Call `NSApp.setActivationPolicy(.accessory)` before `NSApp.run()` instead:

```swift
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
application.run()
```

## When to Use

Use this for local SwiftPM app shells or early prototypes where LSUIElement-style behavior is enough and a full signed `.app` bundle is not yet required.

## Caveat

When the project moves to a proper Xcode app bundle for distribution, restore bundle metadata in the app target's `Info.plist` rather than relying solely on runtime activation policy.
