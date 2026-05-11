# Ken: Multi-display watermark collision / spans-displays diagnostic

**Date:** 2026-05-10T20:30:47.936-04:00  
**Status:** Implemented because root cause was unambiguous in code review

## Minimum diagnostic for Cristian

Run this on the affected machine if behavior remains suspicious:

```bash
echo "=== displays (NSScreen) ==="; osascript -e 'tell application "System Events" to get count of every desktop' 2>&1; echo "=== System Settings → Displays have separate Spaces ==="; defaults read com.apple.spaces spans-displays 2>&1; echo "=== note ==="; echo "spans-displays=1 means one Space spans all displays; 0 or missing means displays have separate Spaces"
```

If `spans-displays` is `1`, macOS is configured for one Space across all displays. That is a system topology choice; the right UX is to tell Cristian to enable **Displays have separate Spaces** or accept one global Space concept.

## Diagnosis

The immediate bug is code-level and independent of the private CGS lookup. `SpaceFingerprinter.currentSnapshots()` already returns one `SpaceSnapshot` per `NSScreen`, and the persistence layer already includes `displayUUID` in CGS exact matching. But `Sources/App/main.swift` selected only `snapshots.first?.identity`, resolved one name, and called `overlayController.updateText(text)`.

`OverlayController` did create one `OverlayWindow` per screen, but it stored one global `currentText`. So every display rendered the first snapshot's name. On Cristian's layout, the top monitor's only Space naturally showed the main monitor's first-Space label.

## Fix shipped

- App now maps every `SpaceSnapshot` to an `OverlayContent(text:screenID:)`.
- `OverlayController` tracks `textsByScreenID` and renders each managed window with its own text.
- Option-click rename now preserves the clicked `screenID`, so a rename on the top display stores against the top display identity instead of the first display identity.
- Tests added for independent per-screen overlay content and screen-targeted rename commits.

## Validation

`swift build --quiet && swift test --quiet` passed: 35 tests, 0 failures.
