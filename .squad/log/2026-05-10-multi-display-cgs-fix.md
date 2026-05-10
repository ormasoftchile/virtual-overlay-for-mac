# Session: Multi-Display CGS Space Identity Correction

**Date:** 2026-05-10  
**Agent:** Ken (reviewer-lockout assignment)  
**Phase:** Diagnosis & bug fix  
**Status:** ✅ Complete

## Problem Statement

Cristian reported all Space overlays showing the same name on a multi-display setup. Don's v1.2 implementation used `CGSGetActiveSpace` for session-scoped Space IDs, which succeeded on single displays but failed on multi-monitor systems due to global behavior.

## Root Cause

`CGSGetActiveSpace` is global to the keyboard-focused display, not per-display. On multi-monitor setups, every overlay resolved to the focused display's Space ID regardless of physical location, causing stored names to cross-wire between monitors.

## Solution

Implemented per-display `CGSManagedDisplayGetCurrentSpace(connection, displayUUID)` lookup for each overlay's NSScreen, preserving session-scoped disambiguation while fixing spatial resolution.

## Fallback Architecture

```
Per-display CGSManagedDisplayGetCurrentSpace 
  ↓ unavailable/invalid
Global CGSGetActiveSpace 
  ↓ unavailable/invalid  
Public heuristic fingerprint
```

Each tier logs diagnostics to stderr.

## Verification

- All 27 tests pass, 0 failures
- Per-display resolution confirmed in regression tests
- GOTCHA comment prevents silent reversion to global CGS call
- Fallback chain validated

## Decision Status

Decision 4 (Ken correction) now supersedes the CGS symbol detail in Decision 3 (Edsger v1.2). The strategy remains; the implementation changes to per-display.
