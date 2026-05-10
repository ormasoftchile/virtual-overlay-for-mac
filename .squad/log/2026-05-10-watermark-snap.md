# Session Log: Watermark Snap (Don-6)

**Timestamp:** 2026-05-10T15:58:36.087-04:00  
**Agent:** Don  
**Work:** Lag fix on Space change

## Brief Summary

Removed 250ms debounce on Space-change notifications that was causing perceptible lag when switching Spaces. Implemented output-side deduplication: `OverlayController.updateText(_:)` no-ops when resolved Space name already matches displayed text.

**Result:** Space switches now update watermark immediately; text changes snap while position animations (hover-flee) remain smooth.

**Tests:** 15 passing, 0 failures

## Decision Created

Decision added to decisions.md: "Drop Space-Change Debounce (SUPERSEDES 250ms debounce approach)"
