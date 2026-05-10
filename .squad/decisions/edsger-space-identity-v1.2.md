# Decision: Space Identity v1.2 — Lift Public-API-Only Constraint

**Author:** Edsger (Lead / Xcode & Architecture)  
**Date:** 2026-05-10  
**Status:** Decided  
**Supersedes:**
- Edsger's v1 public-API-only ratification (2026-05-10, in `decisions.md` §2 and architecture proposal Revision 2)
- Don's Space Identity v1.1 decision (2026-05-10T16:06, in `decisions.md`)

---

## The decision

**Path A — Lift the public-API-only constraint for v1.2.** Introduce a `CGSPrivateSpaceDetector` strategy that calls `CGSGetActiveSpace` (via `CGSMainConnectionID`) to obtain the session-scoped numeric Space ID from Core Graphics Services. This strategy slots behind the existing `SpaceDetectionStrategy` protocol with zero changes to the protocol surface. The public-API `NSWorkspaceSpaceDetector` is retained as the automatic fallback if the private call fails or returns 0.

**Rationale in two sentences:** Public macOS APIs cannot reliably distinguish two Desktop-style Spaces on the same display when they have similar or no foreground apps — Cristian has hit this collision class twice, and Don's v1.1 enrichment of the fingerprint did not resolve it because `CGWindowListCopyWindowInfo([.optionOnScreenOnly])` does not actually scope to the active Space. `CGSGetActiveSpace` returns a per-session unique numeric ID that trivially disambiguates sibling Spaces; the `SpaceDetectionStrategy` protocol was designed for exactly this extension point, and our v1 distribution posture (direct distribution, no App Store, no sandbox) already absorbs the notarization and breakage risks.

---

## What failed

1. **v1 public-API-only identity (Candidate B from Alan's research-05):** Display UUID + window-set Jaccard + ordinal. Failed because `CGWindowListCopyWindowInfo` returns the same window set for sibling Desktop Spaces (Ken's probe-2 was inconclusive; Cristian's empirical results confirm the worst case).

2. **v1.1 enriched fingerprint (Don's decision):** Added `frontmostAppBundleID`, `windowCount`, `windowGeometrySignature`. Failed for the same root cause — when two Spaces have the same foreground app (or no foreground app), the fingerprint is identical. The matcher correctly returns nil (ambiguous), and the watermark shows "UNNAMED", but the user cannot disambiguate through rename because the *next* visit to either Space produces the same fingerprint again, overwriting whichever name was set.

3. **The fundamental limit:** No combination of public signals (display, windows, frontmost app, geometry, ordinal) can distinguish two Spaces that look the same to the windowing server's public interface. Alan's research-05 §6 question 2 flagged this exact risk. Ken's probe-2 could not resolve it without manual multi-Space testing. Cristian's experience is the empirical answer: **the worst case is real and common.**

---

## Why Path A, not B or C

- **Path B (accept the limit, UX-only fix):** When every Space produces the same fingerprint, every visit shows "UNNAMED" and every rename overwrites the same identity. The user *cannot* be the disambiguator if the system cannot tell them which Space they're on. Path B is necessary UX (keep the UNNAMED fallback) but not sufficient.

- **Path C (session-local visit-order tracking):** Fragile — returning to Space 2 after visiting Space 3 produces the same fingerprint as the first visit to Space 2, so the sequence tracker cannot distinguish "returned to slot 2" from "arrived at a new slot." Requires state that doesn't survive app restart. Adds complexity for marginal gain.

- **Path A (private API):** `CGSGetActiveSpace` returns a unique integer per Space per session. It solves the disambiguation problem completely within a session. It doesn't persist across reboots (neither does anything else — Alan's research-01 confirmed this), but combined with the existing `firstSeen` timestamp and user rename, it provides a solid identity anchor. The private-API code is isolated to one file, gated by availability checks, and the public-API path remains as fallback.

---

## Trade-offs accepted

| Risk | Severity | Mitigation |
|------|----------|------------|
| Private API breaks on future macOS | Medium | Isolated behind `SpaceDetectionStrategy` protocol. If `CGSGetActiveSpace` returns 0 or crashes, fall back to public-API strategy automatically. Version-check gate. |
| Notarization rejection | Low-Medium | We already ship outside App Store for v1. Hardened runtime + direct distribution. yabai, AltTab, and others ship with CGS calls via direct distribution. Test notarization submission explicitly. |
| App Store ineligibility | Zero for v1 | Already out of scope per Revision 2. Revisit if/when App Store becomes a goal. |
| Symbol unavailability on Sequoia+ | Low | `dlsym` lookup at runtime. If symbol not found, strategy reports failure and falls back. No link-time dependency. |

---

## New identity shape

The `SpaceIdentity` struct gains one field:

```swift
/// The CGS Space ID observed at detection time. Session-scoped; not stable across reboots.
/// nil when the private-API strategy is unavailable and the public-API fallback is active.
public let cgsSpaceID: UInt64?
```

**Match priority changes:**

1. **CGS exact match (new, highest priority):** If `cgsSpaceID` is non-nil on both current fingerprint and stored entry, and they match, it's the same Space. Done. No fuzzy matching needed.
2. **Signal exact match (existing):** Falls through to `hasSameSignals` when CGS ID is unavailable.
3. **Fuzzy match (existing, unchanged):** Same display + same frontmostApp + Jaccard ≥ 0.8 with winner margin ≥ 0.15.
4. **No match → UNNAMED (existing).**

**Session lifecycle for CGS IDs:** On app launch, all stored `cgsSpaceID` values are treated as stale (set to nil in memory, not persisted). The first visit to each Space after launch populates the CGS ID from the private-API strategy. This handles the fact that CGS IDs don't survive reboots.

---

## Implementation directive for Don

**Goal:** Wire `CGSGetActiveSpace` into the identity pipeline behind the existing strategy protocol. No changes to `SpaceDetectionStrategy`, `OverlayRenderer`, or `Interaction`.

### Step 1 — Add CGS declarations (new file)

Create `Sources/SpaceDetection/CGSPrivate.swift`:

```swift
import CoreGraphics

// Runtime-resolved private CGS symbols. These are not linked at build time.
// If the symbols are unavailable (future macOS), all lookups return nil/0.

typealias CGSConnectionID = Int32
typealias CGSSpaceID = UInt64

private let cgsHandle: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY
)

let CGSMainConnectionID: (() -> CGSConnectionID)? = {
    guard let handle = cgsHandle,
          let sym = dlsym(handle, "CGSMainConnectionID")
    else { return nil }
    return unsafeBitCast(sym, to: (() -> CGSConnectionID).self)
}()

let CGSGetActiveSpace: ((CGSConnectionID) -> CGSSpaceID)? = {
    guard let handle = cgsHandle,
          let sym = dlsym(handle, "CGSGetActiveSpace")
    else { return nil }
    return unsafeBitCast(sym, to: ((CGSConnectionID) -> CGSSpaceID).self)
}()
```

Use `dlsym` — no link-time dependency, no header import. If the symbol vanishes on a future macOS, the optionals are nil and the fallback path activates.

### Step 2 — Add `cgsSpaceID` to `SpaceIdentity`

Add `public let cgsSpaceID: UInt64?` to `SpaceIdentity`. Default it to `nil` in the `init(from decoder:)` path so existing JSON entries decode without migration. Update `hasSameSignals` to compare `cgsSpaceID` when both sides are non-nil.

### Step 3 — Populate CGS ID in `SpaceFingerprinter`

In `SpaceFingerprinter.currentSnapshots()`, after building the fingerprint, attempt:

```swift
let cgsID: UInt64? = {
    guard let mainConn = CGSMainConnectionID,
          let getActive = CGSGetActiveSpace
    else { return nil }
    let id = getActive(mainConn())
    return id > 0 ? id : nil
}()
```

Pass `cgsID` into the `SpaceIdentity` initializer.

### Step 4 — Update match priority in `JSONFileSpaceNameStore`

In `match(currentFingerprint:)`, before the existing exact-signal match, add:

```swift
// CGS exact match — highest confidence, no ambiguity possible.
if let currentCGS = currentFingerprint.cgsSpaceID, currentCGS > 0 {
    if let cgsMatch = names.keys.first(where: { $0.cgsSpaceID == currentCGS && $0.displayUUID == currentFingerprint.displayUUID }) {
        // Refresh volatile signals, keep the stored name.
        let refreshed = cgsMatch.refreshingSignals(from: currentFingerprint)
        if let name = names.removeValue(forKey: cgsMatch) {
            names[refreshed] = name
            save()
        }
        return refreshed
    }
}
```

### Step 5 — Invalidate stale CGS IDs on launch

In `JSONFileSpaceNameStore.init`, after loading from disk, nil out all `cgsSpaceID` values (they don't survive across sessions). Do this in memory only — the first match/rename cycle will write refreshed entries to disk.

### Step 6 — Confidence upgrade

When `cgsSpaceID` is non-nil and matched, set `SpaceDetectionConfidence` to `.high`. This is the first time v1 reaches high confidence.

### Step 7 — Tests

- Add a test that two `SpaceIdentity` values with different `cgsSpaceID` but identical public signals match to different stored names.
- Add a test that when `cgsSpaceID` is nil on the current fingerprint, fallback to existing signal/fuzzy matching works unchanged.
- Add a test that stale CGS IDs (loaded from disk) don't prevent matching when a fresh CGS ID is available.

### What NOT to change

- `SpaceDetectionStrategy` protocol — no changes needed. The CGS call is inside the fingerprinter, not a separate strategy. The protocol extension point remains for future use (e.g., a full CGS strategy that enumerates all Spaces).
- `OverlayRenderer` — no changes.
- `Interaction` — no changes.
- The UNNAMED fallback — keep it. If CGS is unavailable AND public signals are ambiguous, UNNAMED is still the correct answer.

---

## Reversal acknowledgment

This decision explicitly reverses my own v1 public-API-only ratification. The ratification was correct given the information available at the time — Alan's research showed that even private CGS UUIDs don't persist across reboots, which made private APIs seem low-value. What we underestimated was the **within-session disambiguation** value of `CGSGetActiveSpace`: it doesn't solve persistence, but it does solve identity, and identity was the actual blocker. The right call today is more important than consistency with yesterday's right call.
