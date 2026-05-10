# Research: Prior Art Survey (Spaces & Overlay Tools)

**Date:** 2026-05-10  
**Researcher:** Alan  
**Status:** Initial

---

## Question

How do existing macOS tools (Hammerspoon, yabai, Übersicht, AltTab, Rectangle, Stay, and similar projects) handle Space identity, overlay visibility, and persistent window management? What can we learn, and what mistakes should we avoid?

---

## Prior Art Summary

### 1. Hammerspoon (hs.spaces module)

**Project:** https://github.com/asmagill/hs._asm.undocumented.spaces  
**Type:** Lua scripting framework for macOS automation; `hs.spaces` is a third-party extension (not bundled by default).

**What it does:**
- Detects active Space via private CGS API (`CGSGetActiveSpace`).
- Enumerates all Spaces per display.
- Allows scripting to move windows between Spaces.
- Watches for Space changes and triggers custom Lua callbacks.

**Relevant APIs used:**
- `spaces.activeSpaceOnScreen(uuid)` — current Space ID on given display.
- `spaces.spacesForScreen(uuid)` — list of Space IDs on display.
- `spaces.windowSpaces(windowID)` — which Spaces a window occupies.
- `spaces.watcher.new(callback)` — detect Space changes.

**What we can borrow:**
- Space change watcher pattern; use `NSWorkspaceActiveSpaceDidChangeNotification` (public equivalent).
- Awareness that Space IDs are per-display (display UUID is key).

**What they got wrong / limitations:**
- Relies entirely on private APIs; breaks with every major macOS update (Hammerspoon team updates frequently).
- No stable Space identifiers across reboots (documented limitation; users accept this).
- Mission Control must not be open for some operations (architectural limit of CGS).
- High barrier to entry (Lua + manual module install); not suitable for end-user overlay.

**Confidence:** High (well-documented project, active maintenance).

---

### 2. yabai (Tiling Window Manager)

**Project:** https://github.com/koekeishiya/yabai  
**Type:** Full window manager replacement; heavy use of private APIs and scripting additions.

**What it does:**
- Detects active Space and queries all Spaces.
- Moves windows between Spaces.
- Tiles windows within Spaces.
- Exposes CLI interface (`yabai -m query --spaces`, etc.) for shell scripting.

**Relevant APIs used:**
- `CGSGetActiveSpace(cid)` — current Space ID.
- `CGSCopySpaces(cid, selector)` — enumerate all Spaces.
- `CGSCopyManagedDisplaySpaces(cid)` — detailed Space metadata (UUID, type, windows list).
- Requires SIP (System Integrity Protection) to be disabled on Intel; not available on Apple Silicon without workarounds.

**What we can borrow:**
- Robust multi-display Space handling.
- JSON query interface pattern (could inspire CLI for future versions).
- Active maintenance for compatibility; yabai team updates for every macOS release quickly.

**What they got wrong / limitations:**
- **Accessibility nightmare:** Requires disabling SIP, which is a non-starter for end users.
- **Not notarization-safe:** Private APIs detected by notarization service.
- **Breaks frequently:** Every macOS update requires symbol verification and code updates.
- **Not App Store eligible:** Obviously.
- **Heavy footprint:** Overkill for a simple watermark overlay.

**Confidence:** High (production tool; real users rely on it).

---

### 3. Übersicht (Widget Engine / Overlay)

**Project:** https://github.com/felixhageloh/ubersicht  
**Type:** Desktop widget engine; displays HTML/CSS/JavaScript overlays on desktop and all Spaces.

**What it does:**
- Renders custom HTML/CSS/JS overlays on the desktop (below application windows).
- Each widget is a separate window with configurable position and styling.
- Supports transparency, click-through, and dynamic updates.
- Widgets persist across Space changes (using `.canJoinAllSpaces`).

**Relevant APIs used:**
- `NSWindow.collectionBehavior = [.canJoinAllSpaces, ...]` — widget visibility.
- `NSWindow.level = .floating` or `.desktop` — z-order control.
- Custom HTTP server to receive updates from shell scripts or JavaScript.

**What we can borrow:**
- **Best reference for our use case.** Pure AppKit + Cocoa, no private APIs required for basic overlay.
- Window configuration recipe: `.canJoinAllSpaces`, `.fullScreenAuxiliary` proven to work.
- Update mechanism: shell script hooks → HTTP POST to overlay app for dynamic content updates.

**What they got wrong / limitations:**
- Widgets render *below* application windows (using `.desktop` level), not above (we need `.floating`).
- Not designed for always-on-top overlays; designed for desktop background.
- Widgets can't easily be clicked-through (requires manual event handling).
- Update latency: HTTP polling / callbacks can lag.

**What we should do differently:**
- Use `.floating` level (not `.desktop`) for above-application visibility.
- Use `ignoresMouseEvents = true` for true click-through (Übersicht doesn't do this by default).
- Consider embedding text directly in Swift/SwiftUI (not HTML rendering) for simplicity.

**Confidence:** High (production widget engine; GitHub shows active use).

---

### 4. AltTab (Window Switcher)

**Project:** https://github.com/lwouis/alt-tab-macos  
**Type:** Alt+Tab-like window switcher; shows all open windows in current Space (configurable to all Spaces).

**What it does:**
- Displays window switcher overlay (preview grid).
- Filters windows by current Space (default) or all Spaces (configurable).
- Switches to selected window (may trigger Space change if window is on another Space).

**Relevant APIs used:**
- `NSWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, ...]` for the switcher UI itself.
- `NSWindow.ignoresMouseEvents = true` for transitional overlays.
- `CGWindowListCopyWindowInfo(...)` (public API) for enumerating visible windows.
- `NSWorkspace` notifications for app/window changes.

**What we can borrow:**
- Switcher UI appears on all Spaces (using `.canJoinAllSpaces`).
- Works well with fullscreen apps (`.fullScreenAuxiliary`).
- Handles multi-display correctly; creates switcher on active screen.

**What they got wrong / limitations:**
- *Not* truly click-through; requires interaction (you must select a window).
- Overlay is temporary, not persistent (appears on demand, not always visible).
- Heavy rendering for complex layouts; not optimized for minimal footprint.

**Confidence:** Medium-High (production tool; fewer users than yabai or Hammerspoon, but solid).

---

### 5. Rectangle (Snap & Tile Window Manager)

**Project:** https://github.com/rxhanson/Rectangle  
**Type:** Window snapping and tiling utility (macOS equivalent of Windows 10/11 snap).

**What it does:**
- Snaps windows to edges, corners, and thirds via keyboard shortcuts or mouse gestures.
- Shows preview overlay during snap operation.
- Saves window layouts.

**Relevant APIs used:**
- `NSWindow` for window repositioning (public API).
- Snap preview overlay uses `.canJoinAllSpaces` + `.fullScreenAuxiliary`.
- No private APIs or Space-specific logic.

**What we can borrow:**
- Proof that overlays work across all Spaces with public APIs only.
- Snap preview behavior (temporary overlay that appears, updates, then dismisses).

**What they got wrong / limitations:**
- *Cannot* move windows between Spaces (macOS restriction).
- No Space detection or identification (not needed for snapping).
- Preview overlays are temporary, not persistent.

**Confidence:** High (production tool; widely used).

---

### 6. Stay (Window Position Manager)

**Project:** https://cordlessdog.com/stay/ (closed-source commercial app)  
**Type:** Window position restoration and management per-display.

**What it does:**
- Saves window positions and layouts per display.
- Restores layouts when windows are closed/reopened.
- *Cannot* move windows between Spaces (macOS limitation).

**Relevant APIs used:**
- `NSWindow` positioning (public API).
- No Spaces-specific logic; treats each Space independently.

**What we can borrow:**
- Awareness of macOS architectural limits (can't move windows between Spaces).
- Robust window tracking and positioning logic.

**What they got wrong / limitations:**
- Doesn't attempt Space-aware management (accepts OS limit).
- Not relevant for Space detection.

**Confidence:** High (commercial product; real users trust it).

---

### 7. Mission Control & Spaces Architecture (Apple's Approach)

**How macOS Spaces work (from reverse engineering & documentation):**
- Spaces are managed by the Dock process (`com.apple.dock`).
- Each Space has a numeric ID and optional UUID (from CGS).
- Applications can opt into `.canJoinAllSpaces` to appear everywhere, or be pinned to a specific Space.
- Mission Control (F3) overlays all Spaces and windows; no third-party app can render on top of it.

**What we can learn:**
- Never attempt to overlay Mission Control; it's system-reserved.
- Space changes are coordinated by the Dock; listen for `NSWorkspaceActiveSpaceDidChangeNotification` (the safe way).

**Confidence:** High (from Apple documentation and reverse engineering).

---

## Comparative Table

| Project     | Space Detection | Overlay Behavior | Distribution Risk | Maintenance Burden | Best For |
|-------------|-----------------|------------------|--------------------|-------------------|----------|
| **hs.spaces** | Private CGS | Scripting trigger | High (private API) | Very high (breaks often) | Scripting/automation |
| **yabai** | Private CGS | Window management | Very high (SIP required) | Very high (active) | Power users only |
| **Übersicht** | None (triggers only) | `.canJoinAllSpaces` all-Spaces overlay | Low (public APIs) | Low (stable) | **Our closest precedent** |
| **AltTab** | Public API (window lists) | `.canJoinAllSpaces` temporary overlay | Medium (mostly public) | Low | Window switching |
| **Rectangle** | None needed | `.canJoinAllSpaces` preview overlay | Low (public APIs) | Low | Window snapping |
| **Stay** | None needed | Per-display positioning | Low (public APIs) | Low | Layout restoration |

---

## Lessons Learned

### ✅ Good Practices (Verified in Production Tools)

1. **Use public APIs for basic overlay visibility:**
   - `.canJoinAllSpaces` + `.fullScreenAuxiliary` proven reliable across Monterey, Ventura, Sonoma.
   - Abstain from private CGS if you want notarization + Mac App Store viability.

2. **Watch for Space changes via NSWorkspaceActiveSpaceDidChangeNotification:**
   - Public, documented, stable across all modern macOS versions.
   - Use as trigger to refresh watermark or other content.

3. **Render overlays on primary screen by default:**
   - Multi-display support can come later (none of the survey projects prioritized it in v1).

4. **Make overlays click-through if they're purely informational:**
   - `ignoresMouseEvents = true` is the key; used by Übersicht, AltTab.
   - Prevents user frustration with unintended interactions.

### ❌ Mistakes (Learned by Others)

1. **Rely on private APIs for distribution:**
   - yabai and hs.spaces are power-user tools; not suitable for end-user distribution.
   - Private APIs break every OS update; notarization will flag them.

2. **Attempt to query Space IDs persistently:**
   - All projects acknowledge Space IDs are transient (per-session).
   - Accept this limitation; don't design around false persistence.

3. **Try to overlay Mission Control:**
   - Impossible; Mission Control is system-reserved.
   - Don't waste time on this.

4. **Underestimate multi-display complexity:**
   - Even yabai has quirks with multiple screens.
   - Single-display v1 is reasonable; multi-display deferred.

---

## Recommendation for v1 Architecture

**Based on prior art, we should adopt the Übersicht model:**

1. **Use public AppKit APIs only** (NSWindow, NSWorkspace, NSScreen).
2. **Trigger updates via NSWorkspaceActiveSpaceDidChangeNotification**, not private Space detection.
3. **Configure window as `.canJoinAllSpaces` + `.fullScreenAuxiliary` + `.floating` + `ignoresMouseEvents`.**
4. **Render watermark text directly in SwiftUI/CoreGraphics**, not HTML.
5. **Update content via app state (not HTTP callbacks)** to keep complexity low.
6. **Accept single-display in v1; multi-display in v2.**
7. **Target direct distribution (notarization-safe); App Store compatibility deferred until architecture allows it.**

---

## Risk Assessment

| Approach | Risk Level | Mitigation |
|----------|-----------|-----------|
| Public APIs only | **LOW** | Will work across all future macOS versions; notarization-proof. |
| Private CGS APIs | **HIGH** | Will break on OS updates; notarization risk; App Store ineligible. |
| Multi-display in v1 | **MEDIUM** | Adds complexity; defer to v2. |

---

## References

- **Hammerspoon hs.spaces:** https://github.com/asmagill/hs._asm.undocumented.spaces
- **yabai (Spaces module):** https://github.com/koekeishiya/yabai/wiki/Spaces-API
- **Übersicht (source code):** https://github.com/felixhageloh/ubersicht
- **AltTab (window overlay):** https://github.com/lwouis/alt-tab-macos
- **Rectangle (preview overlays):** https://github.com/rxhanson/Rectangle/blob/main/Rectangle/Windowizer.swift
- **Apple Developer (NSWindow documentation):** https://developer.apple.com/documentation/appkit/nswindow

---

## Open Questions

1. **Does Übersicht ever need to know which Space it's on?**
   - **Answer:** No. Widgets are always visible (`.canJoinAllSpaces`); content is refreshed independently.
   - **Implication:** Our watermark may not need Space detection either; just trigger refresh on space changes.

2. **What is the minimal code to render a persistent watermark overlay?**
   - **Probe:** Ken should prototype a minimal SwiftUI + NSWindow overlay app (~100 lines of code).

---

## Summary for Edsger (Architect)

**Adopt the Übersicht model: simple, public-API-based, production-proven overlay architecture.** Don't use private APIs in v1. Accept that watermark won't know *which* Space it's on; instead, trigger refresh on Space change events and let the rendering adapt dynamically. This keeps the codebase notarization-safe and App Store-eligible for future expansion.
