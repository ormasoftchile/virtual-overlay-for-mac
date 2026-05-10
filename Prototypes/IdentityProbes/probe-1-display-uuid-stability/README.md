# Probe 1 — Display UUID Stability

Date: 2026-05-10T15:14:32.937-04:00

Tests public Core Graphics display UUIDs from `CGDisplayCreateUUIDFromDisplayID` alongside `NSScreen.localizedName`, display ID, and frame.

Run:

```bash
swift build && swift run
```

For stronger validation, run once, quit, run again, then unplug/replug an external display and run again. UUIDs should remain non-empty and stable per physical display.
