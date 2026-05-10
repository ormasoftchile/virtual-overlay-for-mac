# Probe 5 — Sequoia Notification Reliability

Date: 2026-05-10T15:14:32.937-04:00

Stress-tests public `NSWorkspace.activeSpaceDidChangeNotification` timing and duplication behavior. It logs every notification, timestamp, delta from previous notification, frontmost app, window count, and `userInfo`.

Run:

```bash
swift build && swift run
```

During the 60-second run, rapidly switch Spaces, enter and exit fullscreen apps, and plug/unplug an external display if available. The baseline result checked in by Ken was run without interaction, so it cannot prove reliability under stress.
