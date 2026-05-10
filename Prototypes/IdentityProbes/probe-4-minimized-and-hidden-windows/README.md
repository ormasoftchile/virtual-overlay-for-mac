# Probe 4 — Minimized and Hidden Windows

Date: 2026-05-10T15:14:32.937-04:00

Compares three public `CGWindowListCopyWindowInfo` option sets: `.optionOnScreenOnly`, `.optionAll`, and `.optionOnScreenOnly + .excludeDesktopElements`.

Run:

```bash
swift build && swift run
```

For stronger validation, run before and after minimizing a known window. Minimized windows are expected to drop from `onScreenOnly` and remain discoverable only in the noisy `.optionAll` result.
