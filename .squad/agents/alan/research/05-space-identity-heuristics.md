# Research: Space Identity Heuristics for Persistence

**Date:** 2026-05-10  
**Researcher:** Alan  
**Status:** Initial  
**Audience:** Don (Persistence module lead)  
**Constraint:** Public APIs only; no private CGS in v1 per Edsger's ratification.

---

## Question

Public macOS APIs provide no stable Space identifier across reboots or even within a session. When a Space-change notification fires, how can the app match the current Space against stored identities using only public signals? What fingerprint of observable properties (display, position, windows, wallpaper, etc.) gives the best "this is probably the same Space" heuristic?

---

## Findings

### 1. Available Observable Signals (Public APIs Only)

#### 1a. Display Identity (NSScreen)

**What it is:**  
The physical display the Space lives on. Each display is a distinct virtual desktop domain; Spaces don't migrate between displays without explicit user action.

**How to observe (public API):**
```swift
NSScreen.screens  // Array of all connected displays
NSScreen.main     // Primary display

// Inspect a screen:
screen.displayID                    // CGDirectDisplayID (Core Graphics, public)
screen.deviceDescription            // NSDictionary with display info
screen.localizedName                // User-facing display name (e.g., "LG 27" Display")
screen.frame.origin                 // Position in virtual coordinate space

// Extract display UUID (public Core Graphics):
let displayID = screen.displayID
if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID) {
    let uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuid) as String
    // Use this as display fingerprint
}
```

**Stability:**
- **UUID via `CGDisplayCreateUUIDFromDisplayID`:** ✅ STABLE across reboots (this is the hardware identifier).
- **Display name (`localizedName`):** ⚠️ User-configurable; may change if user renames in Settings.
- **Ordinal position in `NSScreen.screens`:** ⚠️ Unstable if user connects/disconnects monitors.

**Distinctiveness:**
- ✅ Highly distinctive: identifies the physical display uniquely (until user unplugs/replaces it).
- ✅ Ideal for multi-display setups.

**Confidence:** **HIGH** — UUID from `CGDisplayCreateUUIDFromDisplayID` is part of public Core Graphics; used in production by many macOS tools.

**Notes:**
- If display is unplugged, Spaces migrate to remaining displays. The app should handle this gracefully (reassign stored Spaces to available displays, or label them "missing display").

---

#### 1b. Ordinal Index Within Display

**What it is:**  
The position of the Space in the left-to-right order within a given display (Desktop 1, Desktop 2, Desktop 3, etc.).

**How to observe (public API):**
```swift
// Problematic: NSScreen provides no public API to query Space indices.
// Workaround: Use the private CGSCopySpaces() to enumerate, but that's forbidden in v1.
// 
// Within our own tracking:
// When a Space change notification fires, we can infer ordinal by:
// 1. Observing which Space becomes active (via private CGSGetActiveSpace, but that's also forbidden).
// 2. Falling back to heuristic: match by other signals (display + windows), then assign ordinal retroactively.
```

**Stability:**
- ⚠️ UNSTABLE — User can reorder Spaces in Mission Control, breaking index-based tracking.
- Can only be inferred from our own stored history; not exposed by public APIs.

**Distinctiveness:**
- ⚠️ Weak — ordinal changes if user reorders Spaces, breaking the identity.
- ⚠️ Not unique — two displays can both have a "Desktop 1".

**Confidence:** **LOW** — No public API exposes Space ordinal. Can infer from sequence of notifications + heuristic matching, but fragile.

**Recommendation:** Ordinal is useful as a **secondary** match signal (if display matches and ordinal is stable, it's likely the same Space), but insufficient alone.

---

#### 1c. Fullscreen vs Standard Space Type

**What it is:**  
- **Standard Space:** Regular desktop where normal windows live.
- **Fullscreen Space:** Created when user enters fullscreen mode on an app (e.g., fullscreen Chrome, fullscreen Xcode).

**How to observe (public API):**
```swift
// Indirect approach: enumerate all windows and check collection behavior.
// Standard spaces typically have mixed window levels and collection behaviors.
// Fullscreen spaces typically have a fullscreen app window at `.screenSaver` or `.modalPanel` level.

// Query active app:
let activeApp = NSWorkspace.shared.frontmostApplication
// Iterate windows of active app; check if any are in fullscreen collection behavior.

// Per-window check:
window.collectionBehavior.contains(.fullScreenAuxiliary)   // True if fullscreen-aware
window.level == .screenSaver || window.level == .modalPanel  // Often used for fullscreen

// Heuristic: If the active window is fullscreen-capable and at a high level, likely a fullscreen Space.
```

**Stability:**
- ✅ STABLE within session — user toggling fullscreen is a deliberate action.
- ⚠️ Changes on reboot — fullscreen app might not resume in fullscreen state.

**Distinctiveness:**
- ⚠️ Weak — fullscreen Spaces are often transient; user creates/destroys them frequently.
- ✅ Good for distinguishing "named Desktop" from "fullscreen Chrome".

**Confidence:** **MEDIUM** — Can infer fullscreen status via window enumeration, but heuristic-based and fragile if window visibility quirks apply.

**Recommendation:** Include as a **tertiary** match signal (improves distinctiveness for fullscreen app Spaces).

---

#### 1d. Set of Visible Windows (Names, Apps, Bundles)

**What it is:**  
The list of app windows currently visible on the Space, with their owning app bundle and window title.

**How to observe (public API):**
```swift
// Public API: CGWindowListCopyWindowInfo (Core Graphics, public)
// Filters: kCGWindowListOptionOnScreenOnly (skip off-screen windows)
// Attributes: kCGWindowOwnerName, kCGWindowName, kCGWindowLayer, etc.

let windowList = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] ?? []

for window in windowList {
    let appName = window[kCGWindowOwnerName as String] as? String ?? "Unknown"
    let windowTitle = window[kCGWindowName as String] as? String ?? ""
    let layer = window[kCGWindowLayer as String] as? Int ?? 0
    
    // Use appName + windowTitle as a window fingerprint
    // Sort alphabetically to create a stable signature
}

// Create a stable fingerprint:
let windowSignature = windowList
    .map { ($0[kCGWindowOwnerName as String] as? String ?? "?", 
            $0[kCGWindowName as String] as? String ?? "?") }
    .sorted { $0.0 < $1.0 }  // Stable ordering
    .map { "\($0.0):\($0.1)" }
    .joined(separator: ";")
```

**Stability:**
- ⚠️ VOLATILE — Windows open, close, and move between Spaces frequently during a work session.
- ✅ STABLE at key moments — when user switches to a particular Space and leaves it, the window set is unlikely to change immediately.
- ⚠️ False matches possible — two Spaces could have the same apps open (e.g., two Spaces both with Chrome, Mail).

**Distinctiveness:**
- ⚠️ Weak for generic Spaces (most Spaces have Chrome, Mail, Terminal).
- ✅ Strong for specialized Spaces (e.g., only Xcode on a Space is distinctive).

**Confidence:** **MEDIUM-HIGH** — `CGWindowListCopyWindowInfo` is public API. Stability is good within a session (windows don't shuffle randomly), but user actions (opening/closing apps) break it quickly.

**Recommendation:** Include as a **match signal** but with low weight. Useful as a **mismatch detector** (if window set is radically different, it's probably not the same Space).

---

#### 1e. Wallpaper / Desktop Picture

**What it is:**  
The desktop background image path or settings for the Space.

**How to observe (public API):**
```swift
// Check if public API exists:
// NSWorkspace has methods for getting desktop image, but only *per display*, not per Space.
// Example:
let desktopImage = NSWorkspace.shared.desktopImageURL(for: screen)
// This returns the wallpaper for the *display*, not the Space.

// Problem: macOS does NOT expose per-Space wallpaper via public APIs.
// The wallpaper is stored at ~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.apple.desktop.plist
// But parsing this is unofficial and fragile.
```

**Stability:**
- ⚠️ INACCESSIBLE via public APIs.
- If we attempted private API access (e.g., parsing System Preferences plist), would violate v1 constraint.

**Distinctiveness:**
- ✅ High — users often set distinct wallpapers per Space to visually identify them.

**Confidence:** **LOW** — No public API available. Marked as **v2-only** (see out-of-scope section).

---

#### 1f. First-Seen Timestamp (App-Managed)

**What it is:**  
The moment our app first observed this Space, stored in the Persistence module's local JSON database.

**How to observe (app-managed):**
```swift
// Not observable from system; managed by Persistence module.
// When a new Space is detected (no matching stored identity), record:
struct SpaceRecord {
    let spaceID: String  // Our generated identity (see below)
    let displayUUID: String
    let firstSeen: Date = Date()  // Timestamp when app first detected this Space
    var label: String = ""  // User-set name (or auto-generated if not yet named)
}
```

**Stability:**
- ✅ STABLE — Once set, doesn't change unless user explicitly resets the app state.

**Distinctiveness:**
- ⚠️ Weak — Only useful for breaking ties (if two Spaces look identical, pick the one first seen).

**Confidence:** **HIGH** — Fully under our control; no system API dependency.

---

### 2. Candidate Identity Structures (Ranked by Implementation Cost)

#### Candidate A: Minimal Identity (Display UUID + Ordinal Heuristic)

**Structure (Swift):**
```swift
struct SpaceIdentity {
    let displayUUID: String       // Hardware display ID (via CGDisplayCreateUUIDFromDisplayID)
    let estimatedOrdinal: Int     // 1-based position; may drift if user reorders
    let label: String             // User-set name or auto-generated ("Desktop 2")
}
```

**Signals combined:**
- Display UUID (stable, hardware-based).
- Ordinal (unstable but inferred from notification sequence).
- User label (optional, for disambiguation).

**Resilience:**
- ✅ Survives: User renaming Space, moving windows between Spaces, app restart within session, minor window changes.
- ❌ Breaks: User reorders Spaces in Mission Control (ordinal drifts), user creates/deletes adjacent Spaces (all ordinals shift), system reboot (ordinals reset).

**Implementation cost:** **LOW** — Minimal state tracking. On Space-change notification, increment an ordinal counter per display.

**Failure modes user sees:**
- "After I reordered my Spaces, names got scrambled." (Ordinal matches the wrong Space).
- "After restart, I had to rename everything." (Ordinal pointers were lost; app treats all Spaces as new).

---

#### Candidate B: Medium Identity (Display UUID + Window Set Fingerprint + Ordinal)

**Structure (Swift):**
```swift
struct SpaceIdentity {
    let displayUUID: String                    // Hardware display ID
    let estimatedOrdinal: Int                  // 1-based position
    let windowSignature: String                // Sorted list of app names + window titles
    let label: String                          // User-set name
    let firstSeen: Date                        // Timestamp when first observed
}
```

**Signals combined:**
- Display UUID (stable).
- Ordinal (unstable but inferred).
- Window signature (volatile but distinctive at moments of stability).
- Timestamp (for tie-breaking).

**Resilience:**
- ✅ Survives: User renaming Space, app restart within session.
- ✅ Improves over Candidate A: Can detect "this is probably the same Space despite ordinal drift" by checking if window set + display match.
- ❌ Breaks: Same as Candidate A, PLUS volatile to window changes (opening/closing an app breaks the signature).

**Implementation cost:** **MEDIUM** — Requires querying window list on each Space change, building stable hash, comparing against stored signatures.

**Failure modes user sees:**
- "I opened one more app, and the Space got relabeled." (Window signature changed, triggering fuzzy match to a different stored Space, or treated as new).
- Improved: "After reordering Spaces, names mostly stayed correct!" (Window set helps re-identify Spaces even if ordinal drifted).

---

#### Candidate C: Rich Identity (Display UUID + Window Set + Fullscreen Type + Timestamp)

**Structure (Swift):**
```swift
struct SpaceIdentity {
    let displayUUID: String
    let estimatedOrdinal: Int
    let windowSignature: String         // Sorted window list
    let isFullscreenSpace: Bool         // Fullscreen app Space vs standard desktop
    let label: String
    let firstSeen: Date
}
```

**Signals combined:**
- Display UUID (stable).
- Ordinal (unstable but inferred).
- Window signature (volatile but distinctive).
- Fullscreen type (distinguishes fullscreen Chrome from standard Desktop).
- Timestamp (tie-breaker).

**Resilience:**
- ✅ Survives: Reordering Spaces (window + fullscreen type + display help identify); minor window changes (can apply fuzzy match).
- ✅ Best-in-class at distinguishing different Spaces.
- ❌ Breaks: Same as Candidate B, PLUS if user exits fullscreen (type changes, breaking identity).

**Implementation cost:** **HIGH** — Window enumeration + fullscreen detection logic + fuzzy matching algorithm (e.g., Levenshtein distance on window signatures).

**Failure modes user sees:**
- Improved greatly: "Even after reordering and shuffling windows, my Space names stuck!" (Richer fingerprint survives perturbations).
- Trade-off: More CPU per Space-change event (window enumeration is O(number of windows)).

---

### 3. Recommended v1 Identity

**Pick: Candidate B (Medium Identity) — Display UUID + Window Signature + Ordinal + Timestamp**

**Justification (3–4 sentences):**

Candidate A (minimal) is too fragile; reordering Spaces immediately breaks all ordinal-based tracking, forcing users to re-label everything post-reboot or after reordering. Candidate C (rich) adds marginal resilience gains at significant CPU/complexity cost, and fullscreen-type is a second-order concern for v1. **Candidate B hits the sweet spot:** Display UUID gives us a hardware-anchored root (Spaces don't jump between displays without user intent), window signature provides post-reordering disambiguation (even if ordinal drifts, "Xcode + Chrome on display X" is distinctive enough to survive reordering), and timestamp breaks ties. Implementation is straightforward (one window enumeration per notification + string sorting), and the failure modes are acceptable ("open one app and name might shift slightly" — less bad than ordinal-only).

**Struct shape for Don:**
```swift
struct SpaceIdentity: Codable {
    let id: String                       // Generated UUID or displayUUID-ordinal-timestamp
    let displayUUID: String              // Hardware display identifier
    let estimatedOrdinal: Int            // 1-based Space index within display (may drift)
    let windowSignature: String          // Sorted "AppName:WindowTitle;AppName:WindowTitle;…"
    var label: String                    // User-set name; editable via Interaction module
    let firstSeen: Date                  // Timestamp of first observation
    var lastSeen: Date                   // Updated on each notification
}
```

---

## 4. Match Algorithm

**On each `NSWorkspaceActiveSpaceDidChangeNotification`:**

1. **Extract current fingerprint:**
   ```swift
   let currentFP = extractFingerprint()
   // Captures: displayUUID, windowSignature, estimatedOrdinal (increment per display)
   ```

2. **Exact match (highest confidence):**
   ```swift
   if let exactMatch = storedSpaces.first(where: { stored in
       stored.displayUUID == currentFP.displayUUID &&
       stored.windowSignature == currentFP.windowSignature &&
       stored.estimatedOrdinal == currentFP.estimatedOrdinal
   }) {
       return exactMatch  // Certainty: 100%
   }
   ```

3. **Fuzzy match by display + partial window overlap (medium confidence):**
   ```swift
   let candidates = storedSpaces.filter { stored in
       stored.displayUUID == currentFP.displayUUID  // Same display is required
   }
   
   // Calculate Jaccard similarity on window set
   // (e.g., oldApps={Chrome, Mail}, newApps={Chrome, Mail, Terminal} → 2/3 match)
   let fuzzyMatches = candidates.map { candidate in
       let oldWindows = Set(candidate.windowSignature.split(separator: ";"))
       let newWindows = Set(currentFP.windowSignature.split(separator: ";"))
       let jaccard = Double(oldWindows.intersection(newWindows).count) /
                     Double(oldWindows.union(newWindows).count)
       return (candidate, jaccard)
   }.filter { $0.jaccard >= 0.7 }  // 70% match threshold
    .max { $0.jaccard }  // Pick the best match
   
   if let fuzzyMatch = fuzzyMatches?.0 {
       // Update stored fingerprint to current
       fuzzyMatch.windowSignature = currentFP.windowSignature
       fuzzyMatch.estimatedOrdinal = currentFP.estimatedOrdinal
       fuzzyMatch.lastSeen = Date()
       return fuzzyMatch  // Certainty: medium
   }
   ```

4. **Fallback (treat as new Space):**
   ```swift
   let newSpace = SpaceIdentity(
       id: UUID().uuidString,
       displayUUID: currentFP.displayUUID,
       estimatedOrdinal: currentFP.estimatedOrdinal,
       windowSignature: currentFP.windowSignature,
       label: "Untitled Space",  // or auto-generate "Desktop 3"
       firstSeen: Date()
   )
   storedSpaces.append(newSpace)
   return newSpace  // Certainty: low; user should rename
   ```

**Implementation notes:**
- Exact match should be fast (hash lookup).
- Fuzzy match is O(N) where N = number of stored Spaces (acceptable for typical user with <20 Spaces).
- Jaccard threshold (0.7) tunable; lower = more permissive (risk of false positives), higher = more strict (risk of treating same Space as new).
- After matching, update `lastSeen` and window signature to reflect current state.

---

## 5. Repair UX: Rename as Correction

**Core insight:** The heuristic WILL mislabel. This is not a bug; it's an expected edge case. **The rename interaction (M2 milestone) is the repair mechanism.**

**User flow:**
1. User sees watermark labeled "Untitled Space" (or wrong name).
2. User Option-clicks watermark.
3. Rename dialog appears.
4. User types desired name (e.g., "Xcode Dev").
5. Interaction module updates Persistence.
6. On next Space-change notification, Persistence tags the Space with the new label.

**Why this works:**
- User has direct control; no mysterious auto-correction.
- Each rename is a signal to the app: "I've confirmed this Space's identity."
- App can use rename as a learning signal: anchor the identity more strongly (e.g., boost confidence in window signature match, or lock the label to this fingerprint).

**Document this in Persistence module:**
```
NOTE: If a Space's label doesn't match user expectation, it's likely due to:
- Reordering Spaces in Mission Control (ordinal-based matching breaks).
- Opening/closing apps (window signature changes, triggering fuzzy re-match).
- Display disconnected/reconnected (displayUUID may change if user physically swaps monitors).

None of these are bugs. User should rename the Space via the watermark's Option-click menu.
Future refinements (v2+) will add a "lock identity" feature to prevent re-matches after rename.
```

---

## 6. Open Questions for Ken (Probes Needed)

1. **Can we reliably extract `CGDisplayCreateUUIDFromDisplayID` on Sonoma & Sequoia without crashing?**
   - **What Ken should test:**
     - Create minimal Swift app.
     - Call `CGDisplayCreateUUIDFromDisplayID(mainDisplayID)`.
     - Verify UUID persists across app restart.
     - Verify UUID persists after unplugging secondary display, then replugging.
   - **Why:** Confirm the display UUID is our stable anchor (I'm 95% confident from documentation, but real-Mac confirmation needed).

2. **Does `CGWindowListCopyWindowInfo` include windows from *all* Spaces or only the active Space?**
   - **What Ken should test:**
     - Create two Spaces; open Chrome on Space 1, Mail on Space 2.
     - Switch to Space 1; call `CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)`.
     - Log window count and app names.
     - Switch to Space 2; call same function.
     - Verify: Space 1 returns {Chrome, Mail? or just Chrome?}.
   - **Why:** If it returns all windows from all Spaces, our window signature becomes useless for matching; we'd need private CGS API to filter per-Space (which is out of scope). If it only returns active Space's windows, we're golden.

3. **Can we infer Space ordinal from the *sequence* of notifications without private APIs?**
   - **What Ken should test:**
     - Create 4 Spaces on one display.
     - Switch Space 1 → Space 2 → Space 3 → Space 1 → Space 4.
     - Log the order of `NSWorkspaceActiveSpaceDidChangeNotification` callbacks.
     - Can we infer "Space went from index 1 to 3 to 4" by observing the notification sequence and comparing window sets?
   - **Why:** If the sequence doesn't let us infer ordinal reliably (e.g., if notifications fire out of order or with delays), ordinal becomes truly useless, and we should drop it from identity (simplify to just Display UUID + Window Signature).

4. **Does the window signature remain stable if user minimizes a window (send to Dock)?**
   - **What Ken should test:**
     - Open Chrome + Mail on Space 1.
     - Record window signature via `CGWindowListCopyWindowInfo([.optionOnScreenOnly], …)`.
     - Minimize Mail (⌘M).
     - Query window signature again.
     - Is minimized Mail still in the list, or does it disappear?
   - **Why:** If minimized windows vanish, our fuzzy matching breaks (same Space shows different window signatures when user minimizes apps). We'd need to include minimized windows in the signature (requires different filter flags).

5. **Does `NSWorkspaceActiveSpaceDidChangeNotification` fire reliably on Sequoia (if beta available)?**
   - **What Ken should test:**
     - Run app on Sequoia beta.
     - Switch Spaces repeatedly.
     - Log notifications; confirm one fires per Space switch.
     - No races or dropped notifications.
   - **Why:** Confirm public API stability on new OS versions.

---

## 7. Out of Scope (v2+ Only)

### Wallpaper / Desktop Picture

**Why out of scope:**
- No public API exposes per-Space wallpaper.
- Unofficial parsing of `~/Library/Application Support/com.apple.sharedfilelist/…` violates the spirit of "public APIs only."

**v2 approach (if needed):**
- Use private SkyLight APIs to query Space metadata (wallpaper path, colors, etc.).
- Assess notarization risk; likely high.
- Or: Skip system wallpaper; instead let users associate custom metadata (e.g., color tags, emoji icons) with Spaces.

---

### Private CGS APIs (Full Space Query)

**Why deferred:**
- `CGSGetActiveSpace()` would give us the true current Space ID, eliminating need for heuristic matching.
- `CGSCopySpaces()` + `CGSCopyManagedDisplaySpaces()` would provide rich metadata (fullscreen status, type, layout, etc.).
- **Trade-off:** Notarization risk, maintenance burden, App Store ineligibility.

**v2 approach:**
- Edsger + team agrees to accept private API risk.
- Add conditional compilation: `#if ENABLE_PRIVATE_APIS`.
- Provide clear fallback to public-API heuristics if private APIs unavailable or break.
- Document maintenance burden in v2 pitch.

---

### Space Naming from AI/Heuristics

**Why out of scope:**
- Requires analyzing window titles, app names, and content to auto-generate names (e.g., "Coding Setup" if Xcode + Terminal + Git).
- Adds complexity; better done via explicit user naming (v1 rename interaction).

**v2 approach:**
- ML-based or rule-based auto-naming if users opt in.
- Sync with cloud for cross-device consistency (separate data-sync research needed).

---

## Summary for Persistence Module (Don)

**Data structure:**
```swift
struct SpaceIdentity: Codable {
    let id: String
    let displayUUID: String
    let estimatedOrdinal: Int
    let windowSignature: String
    var label: String
    let firstSeen: Date
    var lastSeen: Date
}
```

**Algorithm:**
1. On notification, extract fingerprint (displayUUID, windowSignature, ordinal).
2. Exact match → return stored Space.
3. Fuzzy match (display + 70% window overlap) → return stored Space (updated).
4. Fallback → create new Space, label "Untitled", await rename.

**Cost:** ~50 lines of matching logic + window enumeration O(N windows) per notification.

**Resilience:** Survives reordering, most window changes, app restarts. Breaks on: display changes, Space creation/deletion (ordinal shift), repeated open/close of apps (window signature volatility).

**Repair:** User renames via watermark option-click. Rename is the primary correction mechanism.

---

## Confidence Summary

| Signal | Confidence | Usage in v1 |
|--------|-----------|-----------|
| Display UUID (via `CGDisplayCreateUUIDFromDisplayID`) | **HIGH** | Primary anchor; required |
| Ordinal (inferred from notification sequence) | **MEDIUM** | Secondary; subject to user reordering |
| Window signature (from `CGWindowListCopyWindowInfo`) | **MEDIUM-HIGH** | Tertiary; fuzzy matching |
| Fullscreen type (inferred from window enumeration) | **MEDIUM** | Not used in v1; considered for v2 |
| Wallpaper | **LOW** | Out of scope; v2+ only |
| Per-Space UUIDs (private CGS) | **HIGH** (technically), **FORBIDDEN** (policy) | Out of scope; v1 constraint |

---

## References & Sources

- **Apple AppKit NSWorkspace:** https://developer.apple.com/documentation/appkit/nsworkspace
- **Apple CGDisplay:** https://developer.apple.com/documentation/coregraphics/cg_display_services
- **Apple CGWindow:** https://developer.apple.com/documentation/coregraphics/cg_window_services
- **yabai Space detection:** https://github.com/koekeishiya/yabai/wiki/Spaces-API
- **Prior art (Übersicht, Rectangle):** Verified in 03-prior-art.md
- **Session history (UUID instability):** Verified in 01-spaces-detection-apis.md

---

**Next steps for Cristian (product lead):**
- Review with Don; confirm Candidate B aligns with Persistence module scope.
- Assign Ken the 5 probes; schedule 1–2 day turnaround for real-Mac testing.
- Edsger: confirm v1 commitment to public APIs + v2 decision point on private CGS.

