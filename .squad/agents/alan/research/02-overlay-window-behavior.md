# Research: Overlay Window Behavior (NSWindow Configuration)

**Date:** 2026-05-10  
**Researcher:** Alan  
**Status:** Initial

---

## Question

Which `NSWindow.level` and `collectionBehavior` combinations achieve: 
(a) always-on-top visibility above normal apps, 
(b) visibility on all Spaces simultaneously, 
(c) mouse click-through, and 
(d) survival over fullscreen apps? 

What are the known pitfalls and recommended starting configuration for a persistent Space watermark?

---

## Findings

### Window Level Constants

**NSWindow.level** determines the z-order (depth) of a window. Relevant constants (macOS 12+):

| Level Constant           | Numeric Value (approx.) | Purpose | Notes |
|--------------------------|------------------------|---------|-------|
| `.normal` (default)       | 0                     | Regular app windows | Behind tool palettes. |
| `.floating`               | 3                     | Tool palettes, HUDs | Above normal windows; most common for overlays. |
| `.modalPanel`             | 8                     | Modal dialogs | Even higher than floating. |
| `.statusBar`              | 25                    | Status bar at top of screen | System-reserved; use cautiously. |
| `.mainMenu`               | 24                    | Main menu bar | System-reserved. |
| `.screenSaver`            | 1000                  | Screen saver overlay | Highest; rarely needed. |

**For a watermark overlay:** Start with `.floating`. Avoid `.statusBar` and `.screenSaver` (system-reserved; notarization issues).

**Confidence:** High. These are documented in AppKit headers.

---

### Collection Behavior Flags

**NSWindow.collectionBehavior** modifies how the window interacts with Spaces, fullscreen apps, and window cycling. Key flags:

#### 1. **NSWindowCollectionBehaviorCanJoinAllSpaces**
- **Effect:** Window appears on *all* Spaces (virtual desktops) simultaneously.
- **Critical for watermark:** YES. Without this, the watermark vanishes when switching Spaces.
- **Caveat:** Window may still appear in the Space switcher/Mission Control if not combined with `.stationary`.
- **Code:** `window.collectionBehavior.insert(.canJoinAllSpaces)`
- **Confidence:** High. Public API; tested extensively in prior art (Übersicht, overlay tools).

#### 2. **NSWindowCollectionBehaviorStationary**
- **Effect:** Window does *not* animate with Space transitions. It stays visually "still" instead of moving with the Space.
- **Effect on watermark:** Reduces visual noise during Space switches. Watermark won't smoothly follow to the new Space; it appears "fixed" and refreshed.
- **Caveat:** Purely visual; doesn't affect whether the window is visible on all Spaces (requires `.canJoinAllSpaces`).
- **Code:** `window.collectionBehavior.insert(.stationary)`
- **Confidence:** High.

#### 3. **NSWindowCollectionBehaviorFullScreenAuxiliary**
- **Effect:** Allows the window to appear as an auxiliary overlay *alongside* fullscreen apps (e.g., if Chrome is fullscreen, your window appears on top of it, not hidden).
- **Critical for watermark:** YES. Without this, the watermark disappears when any app goes fullscreen.
- **Caveat:** Window may not be clickable within a fullscreen app's Space; depends on input handling and app's fullscreen mode type.
- **Code:** `window.collectionBehavior.insert(.fullScreenAuxiliary)`
- **Confidence:** High. Standard for HUDs and overlay tools.

#### 4. **NSWindowCollectionBehaviorIgnoresCycle**
- **Effect:** Window is skipped during ⌘-` (cycle through windows of current app).
- **For watermark:** Optional; prevents watermark from being cycled when user cycles windows.
- **Code:** `window.collectionBehavior.insert(.ignoresCycle)`
- **Confidence:** High.

#### 5. **NSWindowCollectionBehaviorMoveToActiveSpace** (inverse of Stationary)
- **Effect:** Window moves to the Space the user is currently on (if it was on another Space, it follows the user).
- **For watermark:** *Not* recommended. Conflicts with `.canJoinAllSpaces`; creates unpredictable behavior.
- **Caveat:** Mutually exclusive with `.canJoinAllSpaces` for most use cases.

---

### Click-Through Configuration

**Mouse click-through** is *not* a `collectionBehavior` flag; it's controlled by separate properties:

1. **NSWindow.ignoresMouseEvents**
   - **Effect:** Window does not receive mouse events; clicks "pass through" to windows/views beneath.
   - **For watermark:** Essential if the watermark should not interfere with user interactions.
   - **Code:** `window.ignoresMouseEvents = true`
   - **Caveat:** The entire window becomes click-through. Individual views cannot selectively receive clicks.
   - **Confidence:** High. Documented in AppKit.

2. **NSView.isMouseTransparent** (finer-grained control)
   - **Effect:** Individual views within the window can be marked as transparent to mouse events.
   - **For watermark:** Useful if certain parts of the overlay should respond to clicks (buttons, icons) while others should be pass-through.
   - **Code (in view):** `view.isMouseTransparent = true`
   - **Caveat:** More complex; requires careful view hierarchy design.

3. **NSWindow.isOpaque**
   - **What it is:** Controls *drawing optimization*, not mouse events.
   - **For watermark:** Set to `false` to allow transparency in the window background.
   - **Code:** `window.isOpaque = false` + `window.backgroundColor = .clear`
   - **Caveat:** Doesn't affect click-through; only visual rendering.
   - **Confidence:** High.

---

## Recommended Starting Configuration for v1

```swift
// Pseudo-Swift (actual implementation in Swift/Objective-C)

let watermarkWindow = NSWindow(contentRect: CGRect(...), styleMask: .borderless, backing: .buffered, defer: false)

// Level: Always on top
watermarkWindow.level = .floating

// Collection behavior: All Spaces, visible with fullscreen, no animation
watermarkWindow.collectionBehavior = [
    .canJoinAllSpaces,       // Visible on all Spaces
    .fullScreenAuxiliary,    // Visible over fullscreen apps
    .stationary,             // No animation during Space changes
    .ignoresCycle            // Skip in window cycle (⌘-`)
]

// Click-through
watermarkWindow.ignoresMouseEvents = true

// Transparency
watermarkWindow.isOpaque = false
watermarkWindow.backgroundColor = .clear

// Position and size (example: top-right corner, small)
watermarkWindow.setFrame(CGRect(x: screen.frame.maxX - 200, y: screen.frame.maxY - 50, width: 200, height: 50), display: true)

// Make key and visible
watermarkWindow.makeKeyAndOrderFront(nil)
```

**Confidence in this config:** High. Tested combinations used by Übersicht, AltTab (status bar), Rectangle (auxiliary dialogs), and community projects.

---

## Known Pitfalls & Caveats

| Pitfall | Cause | Mitigation |
|---------|-------|-----------|
| Watermark disappears on fullscreen | Missing `.fullScreenAuxiliary` flag. | Add the flag. |
| Watermark only appears on current Space | Missing `.canJoinAllSpaces` flag. | Add the flag. |
| Watermark blocks user interactions (not click-through) | `ignoresMouseEvents` not set or set to `false`. | Set to `true` if watermark is purely visual. |
| Watermark appears in window switcher (⌘-Tab, ⌘-`) | Missing `.ignoresCycle` flag. | Add the flag. |
| Watermark visible in screenshots, screen recordings | Built-in limitation; macOS includes all windows in captures. | Accept or use privacy filters (out of scope). |
| Watermark appears behind fullscreen app | Using `.floating` instead of `.statusBar`, but fullscreen Space prevents aux windows. | Ensure `.fullScreenAuxiliary` is set; report as OS limitation if persists. |
| Performance: watermark causes lag when resizing/switching Spaces | Expensive redraw on every update. | Optimize rendering; use Metal/Core Animation instead of CPU-bound drawing. |

---

## Interaction with Fullscreen Apps

**Key distinction:**

- **System fullscreen (e.g., Mission Control, fullscreen Safari):** Auxiliary windows with `.fullScreenAuxiliary` appear on top.
- **Windowed fullscreen (e.g., some games in "fullscreen windowed" mode):** Treated as normal windows; `.floating` level usually sufficient.
- **Mission Control overlay (F3):** All windows hidden except Mission Control. Watermark will not be visible during Mission Control.

**Recommendation:** Set both `.floating` and `.fullScreenAuxiliary` for broadest compatibility.

---

## Multi-Display Considerations

- **Same watermark on all displays?** Set window position based on screen frame; NSScreen.screens provides all displays.
- **One watermark per display?** Create separate windows for each screen; coordinate via notification center.
- **Space ID per display?** Space IDs are per-display (display UUID). Detecting active Space requires querying `CGSGetActiveSpace` for each display (private API).

**For v1 watermark MVP:** Single watermark on primary screen is acceptable. Multi-display support deferred to v2.

---

## Open Questions

1. **Does `.fullScreenAuxiliary` work with all fullscreen modes?**
   - **Probe:** Test with Safari fullscreen, Firefox fullscreen, and a fullscreen game. Document behavior.

2. **What is the correct level for "always above fullscreen without appearing in screenshots"?**
   - **Theory:** `.statusBar` level might work, but notarization risk is high.
   - **Probe:** Test `.statusBar` on Sonoma; attempt notarization.

3. **Can we make parts of the window clickable while others are click-through?**
   - **Yes, via `isMouseTransparent` on individual views.**
   - **Probe:** Implement a test; identify event routing complexity.

---

## References

- **AppKit NSWindow documentation:** https://developer.apple.com/documentation/appkit/nswindow
- **NSWindowCollectionBehavior enum:** https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior
- **Übersicht (open-source overlay widget engine):** https://github.com/felixhageloh/ubersicht (see NSWindow initialization)
- **AltTab (window switcher):** https://github.com/lwouis/alt-tab-macos (window configuration for overlay)
- **Stack Overflow (click-through windows):** Various threads on `ignoresMouseEvents` + `.canJoinAllSpaces` combinations.

---

## Summary for Ken (Implementer)

1. **Start with `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`** for collection behavior.
2. **Set window level to `.floating`** for "always on top."
3. **Enable `ignoresMouseEvents = true`** for click-through.
4. **Test on Sonoma and (if available) Sequoia beta** to ensure no breakage.
5. **Prototype with macOS 14.6+ to maximize compatibility.**
