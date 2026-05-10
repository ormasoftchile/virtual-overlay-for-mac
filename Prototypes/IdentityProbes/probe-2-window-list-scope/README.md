# Probe 2 — Window List Scope

Date: 2026-05-10T15:14:32.937-04:00

Tests what `CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)` returns on the currently active Space. It prints owner, bundle ID, title, layer, bounds, and intersecting display.

Run:

```bash
swift build && swift run
```

For full validation, open distinctive apps on different Spaces, run this probe on each Space, and compare whether inactive-Space apps appear.
