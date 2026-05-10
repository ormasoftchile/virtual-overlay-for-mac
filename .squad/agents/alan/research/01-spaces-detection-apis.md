# Research: Spaces Detection APIs (Public & Private)

**Date:** 2026-05-10  
**Researcher:** Alan  
**Status:** Initial

---

## Question

What public and private APIs exist on current macOS (Sonoma 14 / Sequoia 15) for detecting the active Space and identifying Spaces individually? Which are production-viable, which are risky, and what should we adopt for the v1 watermark overlay?

---

## Findings

### Public APIs — NSWorkspace & NSScreen

1. **NSWorkspace.activeSpaceDidChangeNotification**
   - **What:** Notification posted when user switches Spaces.
   - **Source:** macOS 10.7+, public API, AppKit framework.
   - **Capability:** Tells your app *that* a Space change happened, but does *not* provide the active Space ID or identifier.
   - **Use in wild:** Hammerspoon (`hs.spaces`), yabai, Übersicht, and many overlay tools use this as the trigger to refresh state.
   - **Confidence:** High — this is stable, documented, notarization-safe.

2. **NSScreen API**
   - **What:** Provides screen/display info (resolutions, positioning).
   - **Limitation:** NSScreen has *no* public API for Spaces or virtual desktop enumeration.
   - **Confidence:** N/A (not applicable for Spaces detection).

---

### Private CGS APIs (Core Graphics Services)

These symbols live in `/System/Library/Frameworks/CoreGraphics.framework` and are **undocumented, unsupported, and liable to break**:

1. **CGSGetActiveSpace(CGSConnectionID cid) → uint64_t**
   - **What:** Returns the numeric ID of the currently active Space on a given display connection.
   - **Used by:** yabai, chunkwm, some Hammerspoon modules, AltTab (optional).
   - **Signature:** `extern uint64_t CGSGetActiveSpace(int cid);`
   - **Availability:** Sonoma (14.x) ✓, Sequoia (15.x) ✓ (unconfirmed; early betas show it present).
   - **Confidence:** High (for *current* versions), but subject to break on any major OS update.

2. **CGSCopySpaces(CGSConnectionID cid, int selector) → CFArrayRef**
   - **What:** Returns array of all Space IDs matching the selector (e.g., `kCGSSpaceAll`, `kCGSSpaceUser`).
   - **Used by:** yabai extensively; some window managers for multi-display setups.
   - **Signature:** `extern CFArrayRef CGSCopySpaces(int cid, int selector);`
   - **Availability:** Sonoma ✓, Sequoia (likely) ✓.
   - **Confidence:** High (for current versions).

3. **CGSCopyManagedDisplaySpaces(CGSConnectionID cid) → CFArrayRef**
   - **What:** Returns array of property-list dictionaries, one per Space, with keys like `"uuid"`, `"windows"`, `"type"`, `"display"`.
   - **Used by:** yabai for detailed Space metadata; occasionally in scripting.
   - **Signature:** `extern CFArrayRef CGSCopyManagedDisplaySpaces(int cid);`
   - **Availability:** Sonoma ✓, Sequoia (likely) ✓.
   - **Confidence:** High (for current versions).

4. **CGSMainConnectionID() → int**
   - **What:** Returns the default CoreGraphics connection ID for the current process.
   - **Used by:** Foundation for all CGS calls.
   - **Signature:** `extern int CGSMainConnectionID(void);`
   - **Availability:** All modern macOS versions.
   - **Confidence:** High.

---

### Space Identifier Stability

**Critical Finding:** No stable, persistent Space identifier exists.

- **UUID Field in CGSManagedDisplaySpaces:**
  - Each Space has a `"uuid"` string field in its dictionary (via `CGSCopyManagedDisplaySpaces`).
  - **Does NOT persist across:**
    - OS reboots (often changes).
    - OS upgrades (always changes).
    - Mission Control modifications (when user adds/removes Spaces).
  - **May persist** between app launches within the same session, but no guarantee.
  - **Source:** Web research, yabai documentation, Stack Overflow reverse-engineering notes.

- **Space Index (numeric order):**
  - Spaces are ordered numerically by position (1st, 2nd, 3rd…).
  - **Problem:** User can reorder Spaces in Mission Control, breaking index-based tracking.
  - **Used by:** Rectangle, Magnet (position-based window snapping), but not for persistent identification.

**Recommendation for v1:** Do *not* attempt to persist Space identity. Instead, use index-based or heuristic identification within a session. Accept that reboots/upgrades will reset any saved state.

---

### Known Breakage History

| macOS Version | Event                                                  | Status |
|---------------|--------------------------------------------------------|--------|
| Monterey 12   | CGSGetActiveSpace, CGSCopySpaces available            | ✓      |
| Ventura 13    | No significant breakage; APIs unchanged               | ✓      |
| Sonoma 14     | APIs unchanged; private symbol availability stable    | ✓      |
| Sequoia 15    | Early betas: APIs present; entitlement checks in flux | ⚠️      |

**Source:** Web research, yabai GitHub issues, developer forums.

---

## Confidence & Recommendation Matrix

| Approach                         | Confidence | Recommendation |
|----------------------------------|-----------|------------------|
| Use `NSWorkspaceActiveSpaceDidChangeNotification` to trigger refresh | **HIGH**   | ✅ **ADOPT** — Safe, public, notarization-proof. Use as the primary mechanism to detect "Space changed" events. |
| Use `CGSGetActiveSpace` for current Space ID  | **MEDIUM** | ⚠️ **USE WITH CAUTION** — Works on Sonoma/early Sequoia, but private. Notarization risk; App Store ineligible. Useful for v1 prototype/direct distribution. |
| Use `CGSCopyManagedDisplaySpaces` for Space metadata | **MEDIUM** | ⚠️ **PROTOTYPE ONLY** — Useful for research/testing, but overkill for a watermark overlay. Risk same as CGSGetActiveSpace. |
| Persist Space identifiers across reboots | **LOW**    | ❌ **DON'T ATTEMPT** — No stable identifier. Accept session-based state only. |

---

## Open Questions & Probes

1. **Does Sequoia 15 still expose these symbols?**
   - **Probe:** Ken or Don should compile against Sequoia SDK on a Sequoia beta machine and verify `CGSGetActiveSpace` still links and runs.

2. **Do private CGS symbols break notarization?**
   - **Probe:** Submit a minimal test app using `CGSGetActiveSpace` to notarization service. Document the response.

3. **Can we layer without identifying the Space?**
   - **Theory:** The watermark doesn't *need* to know the Space ID if we use `NSWorkspaceActiveSpaceDidChangeNotification` to refresh its appearance. Worth exploring.

---

## Recommendation for Architecture

**For v1 (MVP watermark):**

- **Primary trigger:** `NSWorkspaceActiveSpaceDidChangeNotification` to know when to refresh.
- **Space identification (if needed):** Use `CGSGetActiveSpace` for runtime Space ID if targeting direct distribution. Prepare to remove if shipping via App Store.
- **Window behavior:** Pair overlay window with `.canJoinAllSpaces` collection behavior to ensure visibility across all Spaces (public API; safe).
- **Distribution constraint:** If using CGS, direct distribution only (notarization risky; App Store ineligible).

**For v2 (if architecture demands persistence):** Revisit; may require per-user Space naming or heuristic tracking.

---

## References

- **yabai (Space queries):** https://github.com/koekeishiya/yabai/wiki/Spaces-API
- **yabai (CGS headers):** https://github.com/koekeishiya/yabai/tree/master/src/osax/cgs (for up-to-date symbol definitions)
- **Hammerspoon hs.spaces:** https://github.com/asmagill/hs._asm.undocumented.spaces
- **Stack Overflow (Space persistence):** https://stackoverflow.com/questions/42276158/macos-mission-control-spaces-stable-id
- **WWDC 2019 (Private API risk):** Apple developer forums & documentation.
