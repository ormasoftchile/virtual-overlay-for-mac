# Decisions

## Decision: v1 Public-API-Only Architecture

**Author:** Edsger (Lead / Xcode & Architecture)  
**Date:** 2026-05-10  
**Status:** Approved  
**Reviewer:** Edsger (Lead)

---

### Decision

v1 of Virtual Overlay uses **ONLY public macOS APIs**.

Specifically:

- **`NSWorkspace.activeSpaceDidChangeNotification`** is the sole Space-change signal.
- **Private CGS / SkyLight symbols** (`CGSGetActiveSpace`, `CGSCopySpaces`, `CGSCopyManagedDisplaySpaces`, `CGSMainConnectionID`, and anything in `SkyLight.framework`) are **explicitly out of scope for v1**.
- The overlay window uses only documented AppKit APIs: `NSWindow.level`, `NSWindow.collectionBehavior`, `NSWindow.ignoresMouseEvents`, `NSScreen`.

---

### Rationale

1. **Notarization safety.** Alan's research (`04-permissions-and-distribution-risk.md`) confirms that private CGS symbols are detected by Apple's notarization service and will cause rejection or warnings. Public APIs pass clean.

2. **App Store eligibility preserved.** By committing to public APIs now, we keep the Mac App Store door open for v2+ without a rewrite. Apple Review Guidelines §2.5.1 reject apps using non-public APIs — no exceptions.

3. **Zero-permission posture.** `NSWorkspace.activeSpaceDidChangeNotification` requires no Accessibility, Screen Recording, or Input Monitoring permission. The overlay window (`NSWindow` + `collectionBehavior`) requires no permission. v1 shows zero system prompts on first launch. This is a material UX advantage.

4. **Simpler implementation.** No `dlopen`/`dlsym` for private frameworks, no symbol-availability guards, no per-OS-version fallback paths. The detection module ships one strategy instead of a strategy stack.

5. **Eliminates the largest maintenance risk.** Alan's breakage history table (`01-spaces-detection-apis.md`) shows private CGS APIs are stable *today* but have no stability contract. Every major macOS release is a potential breakage event. Public APIs have Apple's backward-compatibility guarantee.

6. **Prior art validates the approach.** Übersicht, Rectangle, and AltTab all ship production overlays using only public APIs (`03-prior-art.md`). Übersicht is the closest precedent to our use case and has been stable for years.

---

### Acknowledged Trade-off

With public APIs only, we **cannot**:

- Enumerate all Spaces on a display.
- Obtain a numeric or UUID Space identifier from the system.
- Persistently identify individual Spaces by a stable, system-provided key.

`NSWorkspace.activeSpaceDidChangeNotification` tells us *that* a Space change happened, but not *which* Space we are now on or *how many* Spaces exist.

**Consequence for v1:** Space identity must be treated as **ordinal-or-best-effort**. The detection module will assign a heuristic identifier (e.g., an incrementing counter per session, or a fingerprint derived from visible windows) that is:

- Stable within a single app session.
- **Not guaranteed stable** across app restarts, reboots, or Mission Control Space reordering.

The persistence schema must document this limitation honestly — both in code comments and in the schema design. User-assigned Space names may become orphaned after a reboot or Space reorder. This is acceptable for v1; the user can re-assign names in seconds.

**v2 path:** The `SpaceDetectionStrategy` protocol is designed to be pluggable. If the ordinal/heuristic approach hurts UX, v2 can introduce a `PrivateCGSStrategy` behind the same protocol without touching the renderer, persistence, or interaction modules.

---

### Constraints on Team Members

#### Ken (Space Detection & Systems)

- Detection strategies **must NOT** import private CGS symbols. No `CGSGetActiveSpace`, no `CGSCopySpaces`, no `CGSCopyManagedDisplaySpaces`, no `CGSMainConnectionID`.
- No `dlopen`/`dlsym` calls to load private frameworks.
- The `SpaceDetectionStrategy` protocol stays — it is the v2 extension point. But **only the public-API strategy ships in v1**.
- The public-API strategy uses `NSWorkspace.activeSpaceDidChangeNotification` as its sole signal source.

#### Don (Persistence & Data)

- The persistence schema **must use whatever identifier the public-API strategy produces** — which will be a heuristic, session-scoped identifier, not a system-provided UUID.
- The `SpaceName` model and its storage must **document the identifier's limitations** in code: it is best-effort, may not survive reboots, and Space names may need re-assignment after system changes.
- Do not design the schema as if stable Space UUIDs exist. They don't in v1.

#### Alan (Research)

- Continue tracking private-API alternatives for v2 in the research corpus.
- **Do not gate v1 on private API findings.** If a new public API appears (e.g., in a future macOS beta), flag it for the team.
- Stand by to update the research corpus when Ken's prototype validates the public-API approach on current macOS.

---

### What This Unblocks

- Ken can begin implementing the `PublicAPISpaceDetectionStrategy` immediately.
- Don can design the persistence schema with honest constraints.
- The signing/build posture simplifies: hardened runtime is now compatible (no private framework loading needed), notarization is achievable at any time.
- M1 milestone is unblocked — all implementation uses only public APIs.

---

### References

- `01-spaces-detection-apis.md` — API survey, stability findings, recommendation matrix.
- `02-overlay-window-behavior.md` — NSWindow configuration, all public API.
- `03-prior-art.md` — Übersicht model validation.
- `04-permissions-and-distribution-risk.md` — Notarization/App Store risk analysis.
- Architecture proposal: `.squad/agents/edsger/proposals/2026-05-10-architecture-v1.md` (Revision 2).

---

## Decision: User Directive — No-Menu Coordination

**Date:** 2026-05-10T15:28:19-04:00  
**From:** ormasoftchile (Cristian) (via Copilot)  
**Status:** Approved

### Decision

Stop offering menus of "next step" choices when the path forward is reasonable. Coordinator should drive — pick the next move and execute. Only ask when input is genuinely required (e.g. design preferences with no obvious default).

### Rationale

User feedback after watermark eyeball indicated that lists of follow-up options were noise ("for the other bs, i don't know what you want"). Decisions should be owned by coordinator/agents, not deferred to the user when a reasonable default exists.

---

## Decision: Watermark Position — Default, Padding, Anchor

**Date:** 2026-05-10T15:28:19.948-04:00  
**From:** Don  
**Status:** Approved

### Decision

Keep the default watermark position at `.lowerRight`, but render it inside `NSScreen.visibleFrame` with 80pt horizontal and 60pt vertical SwiftUI padding.

### Rationale

The user feedback was about position, not style. `visibleFrame` lets AppKit account for Dock and menu bar areas per display, while larger internal padding preserves the ambient, infrastructural feel instead of pinning the text to a screen corner.

### Implementation Notes

- Make watermark position configurable via `WatermarkPosition` enum.
- Wire through `OverlayController`.
- Default padding: 80pt horizontal (left/right offset), 60pt vertical (bottom/top offset).
- Anchor inside safe visible frame.

---

## Decision: Watermark Hover-Flee Behavior

**Date:** 2026-05-10T15:30:14.156-04:00  
**From:** Don  
**Status:** Approved

### Decision

Use a single global mouse-position monitor in `OverlayController` for watermark hover-flee.

### Specific Choices

- Use Option A: `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` plus screen-coordinate hit testing, instead of making the click-through overlay accept mouse events.
- Keep `OverlayWindow.ignoresMouseEvents = true`; click-through behavior is more important than local tracking-area convenience.
- Throttle sampling to 30 Hz and only run flee logic when the cursor crosses a watermark bounds threshold.
- On hover-out, leave the watermark where it fled. No slide-back in v1.
- Animate the SwiftUI watermark position with `.easeInOut(duration: 0.25)`. Do not animate or move the AppKit window.
- Center maps to center for v1, so configured center watermarks do not flee.
- Support all four-corner positions (top-left, top-right, bottom-left, bottom-right).
- On hover, move to diagonally opposite corner.

### Rationale

This keeps the overlay boring and durable: one monitor per controller, no accessibility permission dependency, no click-through regression, and no ping-pong when users move through the screen real estate the watermark previously occupied.

Behavior is derived from prior-art "Virtual Overlay" tool — makes the watermark unobtrusive in practice by getting out of the way precisely when you need the screen real-estate it occupies.

### Product Spec

Watermark must support all four-corner positions (top-left, top-right, bottom-left, bottom-right). When the mouse cursor enters the watermark's bounds, the watermark moves to the diagonally opposite corner to free the space the user is trying to interact with. When the mouse leaves, it stays there until the next hover.

---

## Decision: Use `.floating` Window Level for v1 Overlay Probe

**Date:** 2026-05-10  
**Proposed by:** Ken  
**Status:** Proposed

### Decision

Use `NSWindow.Level.floating` for the v1 watermark overlay prototype and initial renderer implementation.

### Rationale

- `.floating` is a documented AppKit level intended for palettes/HUD-style windows above normal app windows.
- It avoids system-reserved levels such as `.statusBar`, `.mainMenu`, and `.screenSaver`.
- It aligns with the public-APIs-only v1 direction and reduces notarization/App Store/distribution risk.
- Fullscreen survival should be attempted through `collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]`, not by escalating to reserved levels first.

### Deferred

If real-Mac testing proves `.floating` insufficient over some fullscreen or Stage Manager cases, test alternate levels behind the renderer strategy/probe layer before promoting any change to product code.

---

## Decision: LSUIElement via Code and Candidate B Identity

**Date:** 2026-05-10T15:14:32.937-04:00  
**From:** Don  
**Status:** Approved

### Decision

Use `NSApp.setActivationPolicy(.accessory)` at launch for SwiftPM executable builds instead of embedding `Info.plist` through SwiftPM resources or unsafe linker flags.

Adopt Alan's Candidate B Space identity in code: display UUID, window signature, optional ordinal, and first-seen timestamp. Keep the user-visible label in the persistence store rather than inside `SpaceIdentity`, so renames do not mutate the identity key.

### Rationale

SwiftPM forbids top-level `Info.plist` resources for executable targets, and accessory activation covers the current LSUIElement-style behavior without private APIs or linker-section complexity. The identity shape follows Alan's recommendation while keeping Persistence's existing `SpaceIdentity → name` responsibility clean.

---

## Decision: M2 Space Naming Interaction

**Date:** 2026-05-10T15:43:36.730-04:00  
**From:** Don  
**Status:** Approved

### Decision

- Debounce Space-change notifications at 250ms, last-write-wins, before collecting the fingerprint.
- Keep Space fingerprinting in `Sources/SpaceDetection/SpaceFingerprinter.swift`, not the app shell.
- Use Ken's window-list recipe: `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`, then layer-0 app-window filtering.
- Use global and local Option `flagsChanged` monitors to temporarily make overlay windows clickable.
- Treat blur/outside click during rename as cancel for v1; Enter is the only save path, Escape cancels.
- Use `rectangle.dashed` for the discreet menu-bar affordance.

### Reasoning

These choices keep private APIs out, keep `main.swift` as wiring, and make the product loop real without introducing M3 settings or Space-list UI.

---

## Decision: Retire Heuristic CGS Re-bind

**Date:** 2026-05-10T16:28:42.833-04:00  
**From:** Don  
**Status:** Approved  
**Supersedes:** Don-8 / Space Identity v1.2 re-bind-on-first-visit behavior (now retired), Edsger v1.2 CGS re-bind logic component

### Decision

Retire the automatic re-bind logic that matched heuristic-only stored entries (`cgsSpaceID = nil`) to a fresh session CGS Space ID on first visit.

On launch, stale persisted CGS IDs may still be cleared in memory because CGS Space IDs are session-scoped. After that, any entry without a CGS ID is dormant/orphaned data. It must not be matched to or refreshed into a current CGS-backed identity.

### Rename Invariant

Rename submit must capture the Space identity fresh at commit time, using the same `SpaceFingerprinter.currentIdentity()` path used by display refresh. The write must not use an identity cached by `WatermarkView`, `OverlayController`, or a closure captured at click-down / edit-start time.

### Rationale

The re-bind used the same heuristic matching that CGS identity was introduced to replace. In Cristian's failure case ("renamed 2 to second, will always show third"), an old entry named `third` could bind itself to the freshly detected CGS ID for Space 2, causing Space 2 to display `third` forever in that session.

Showing `UNNAMED` until the user renames each Space once under the CGS-backed identity is more honest than guessing.

The fresh rename-time identity capture fixes a read/write drift bug discovered during the rename path audit: `OptionClickRenameController` was capturing identity at rename start and reusing it on commit, which stale re-bind logic could then misroute to the wrong Space.

### Follow-up, not part of this change

Dormant heuristic-only orphan entries can be garbage-collected later, but this decision does not ship a cleanup feature.
