# Probe 3 — Space Change Notification Info

Date: 2026-05-10T15:14:32.937-04:00

Subscribes to `NSWorkspace.activeSpaceDidChangeNotification`, logs timestamp, full `userInfo`, and an immediate `CGWindowListCopyWindowInfo([.optionOnScreenOnly])` snapshot. This uses public AppKit/Core Graphics APIs only.

Run:

```bash
swift build && swift run
```

During the 60-second run, manually switch Spaces a few times. The baseline result checked in by Ken was run without interaction, so absence of notifications there only proves idle behavior.
