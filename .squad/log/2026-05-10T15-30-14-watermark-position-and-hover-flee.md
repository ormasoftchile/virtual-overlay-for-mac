# Session Log: Watermark Position and Hover-Flee

**Date:** 2026-05-10T15:30:14-04:00  
**Topic:** Watermark UX — Position Configurability + Hover-Flee  
**Coordinator Batch:** Don-2 & Don-3

## Summary

Two Don runs completed watermark UX improvements:

1. **Don-2:** Watermark position now configurable via `WatermarkPosition` enum. Default `.lowerRight` with 80pt H / 60pt V padding inside safe visible frame. Wired through `OverlayController`. 8 tests passing.

2. **Don-3:** Hover-flee behavior implemented. Global mouse monitor at 30 Hz (click-through preserved), diagonally opposite corner flee on hover, 0.25s ease-in-out animation. Center position no-op. 10 tests passing.

## User Directive Applied

- "No-menu" coordination: Both runs were driven by product spec and prior-art behavior, not deferred to user for next-step menus.

## Decision Archive

Three decisions merged into canonical store:
- User Directive: No-menu coordination
- Watermark Position default & padding
- Watermark Hover-Flee behavior (full spec + rationale)

## Next Steps

Product complete for watermark UX cycle. Watermark now:
- Configurable at all four corners with safe-frame padding
- Automatically flees to opposite corner on hover
- Animates smoothly (0.25s)
- Preserves click-through behavior

Ready for next team focus.
