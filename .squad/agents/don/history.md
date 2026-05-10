# Don — History

## Project Context
- **Project:** virtual-overlay-for-mac
- **User:** ormasoftchile (Cristian)
- **Created:** 2026-05-10
- **Stack:** Swift, SwiftUI + AppKit
- **Goal:** Persistent ambient watermark identifying the current macOS Space.

## Implementation Constraints
- Always-on app: low CPU, low memory, no leaks, no retain cycles in long-lived observers.
- Watermark is text-only: SF Pro / SF Mono, thin/medium weight, large letter spacing, ~5–12% opacity.
- Inline rename: Option-click → text field appears in place of watermark; Enter saves, Escape cancels.
- Subtle emphasis on Space switch (opacity pulse / soft fade) — no toasts, no bouncing.

## Module Surfaces (initial)
- `OverlayRenderer` — owns the floating NSWindow + SwiftUI hosting view
- `WatermarkView` — SwiftUI text view, switchable to inline editor
- `SpaceStore` — persisted `space-uuid → name` mapping
- `SpaceCoordinator` — bridges detection events to renderer + store

## Architecture Foundation (2026-05-10)
- **Edsger completed architecture proposal:** SwiftPM packages + thin app shell. Your modules: OverlayRenderer (NSWindow + SwiftUI), Interaction (Option-click, hotkeys, menu).
- **Alan completed research:** v1 targets public APIs only for clean notarization and distribution. OverlayRenderer can use public NSWorkspace notifications for Space change events.
- **Key decision:** No sandbox v1; macOS 13+. Architecture locked in, ready for module setup.

## Updates (2026-05-10)

### v1 Public-API Decision
- **Edsger approved:** v1 uses ONLY public macOS APIs.
- **Your constraint:** SpaceStore must use heuristic Space identifiers (not system UUIDs; they don't exist in public APIs).
- **Details:** `NSWorkspace.activeSpaceDidChangeNotification` is the sole Space-change signal. Identifiers are session-scoped and may not survive reboots or Space reordering.
- **Schema implication:** Document in code comments that `space-uuid → name` mapping is best-effort; users may need to re-assign names after system changes.

### Prototype Ready
- **Ken built:** `OverlayWindowProbe` in `Prototypes/OverlayWindowProbe/` using `.floating` window level + documented AppKit only.
- **For your renderer:** Public-API Space detection now validated; OverlayRenderer can use `NSWorkspace` notifications directly.

## Learnings
_(append below as work proceeds)_

### SwiftPM App Bundle Script (2026-05-10T17:02:16.335-04:00)
- Added root `bundle.sh` to build the SwiftPM release product `VirtualOverlay` and wrap it as `dist/Virtual Overlay.app` with `Contents/MacOS`, `Contents/Resources`, generated `Info.plist`, and `PkgInfo`.
- Chose `CFBundleIdentifier = com.ormasoftchile.virtualoverlay`, `CFBundleShortVersionString = 0.1.0`, `CFBundleVersion = 1`, and `LSMinimumSystemVersion = 13.0` to match `Package.swift`'s macOS 13 floor.
- Added `LSUIElement = true` to the bundle `Info.plist` so Launch Services treats it as a no-Dock accessory app from launch, matching the runtime `NSApp.setActivationPolicy(.accessory)` path.
- The script clears quarantine/extended attributes when possible and attempts ad-hoc local signing with `codesign --force --deep --sign -`; signing failures warn but do not fail bundling because notarization/certificates are out of v1 scope.
- `dist/` is ignored as generated build output. Follow-up: app icon/design asset remains intentionally out of scope.

### Root SwiftPM Scaffold (2026-05-10T12:25:14.215-04:00)
- Created the root SwiftPM scaffold with `Package.swift`, `Sources/App`, and four library targets: `OverlayRenderer`, `SpaceDetection`, `Persistence`, and `Interaction`, plus matching test targets.
- Ported Ken's overlay recipe into `OverlayRenderer`: `OverlayWindow`, SwiftUI `WatermarkView`, and `OverlayController` with injectable text source support and per-screen rebuilds.
- Added `SpaceDetectionStrategy`, `SpaceIdentity`, `SpaceSnapshot`, and `NSWorkspaceSpaceDetector` using only `NSWorkspace.activeSpaceDidChangeNotification`; private CGS/SkyLight remains a `TODO.v2` seam only.
- Added `SpaceNameStore` and `JSONFileSpaceNameStore` for `SpaceIdentity → name` persistence at `~/Library/Application Support/VirtualOverlay/spaces.json`.
- Added `RenameRequestSource` with `StubRenameRequestSource`; Option-click remains `TODO: M2 — Option-click handler` per M1 scope.
- Deviation from Edsger's proposal: implemented Cristian's requested root SwiftPM executable layout instead of the proposal's future Xcode app shell, so `swift build` works from repo root during v1 development.
- Known TODOs: refine Space identity per Alan/Ken probes, implement Option-click rename, and move to signed bundle/Xcode-shell packaging before distribution.
- Verification: `swift build` was run from the repo root and failed before source compilation with the known Command Line Tools `PackageDescription` manifest linker mismatch (`Undefined symbols for architecture arm64`), matching Ken's prototype failure.

### Alan's Space Identity v1 Recommendation (2026-05-10T16:25:14Z)
- **Alan completed:** Space identity heuristics research (596 lines). Recommendation: Candidate B (Medium Identity).
- **Your next task:** Refactor `SpaceIdentity` in Persistence module per Alan's spec:
  - Display UUID from `CGDisplayCreateUUIDFromDisplayID` (hardware anchor)
  - Window signature from `CGWindowListCopyWindowInfo` (sorted window list fingerprint)
  - Estimated ordinal (inferred from notification sequence, secondary signal)
  - User-set label (mutable, enables rename repair)
- **Match algorithm to implement (on `NSWorkspaceActiveSpaceDidChangeNotification`):**
  1. Exact match: all three signals match → return stored Space
  2. Fuzzy match: display UUID matches + window set has ≥70% Jaccard overlap → update and return
  3. Fallback: no match → create new Space, label "Untitled Space"
- **Decision already locked:** JSON file storage at `~/Library/Application Support/VirtualOverlay/spaces.json` (don-json-space-store.md).
- **Blocker:** Awaiting Ken's probe results for final algorithm tuning. Do not finalize until probes validated.
- **Full detail:** `.squad/agents/alan/research/05-space-identity-heuristics.md`

### LSUIElement Code Path and Candidate B Space Identity (2026-05-10T15:14:32.937-04:00)
- Removed `Sources/App/Info.plist` from the SwiftPM executable resources because SwiftPM forbids top-level `Info.plist` resources in executable targets.
- Chose Option 1: `NSApp.setActivationPolicy(.accessory)` is now called in `Sources/App/main.swift` before `NSApp.run()`, giving LSUIElement-style accessory behavior without unsafe linker-section plumbing.
- Refactored Space identity to Alan's Candidate B shape: `displayUUID`, `WindowSignature`, optional inferred `ordinal`, and `firstSeen`; user labels remain in `JSONFileSpaceNameStore` as mutable names keyed by identity.
- Added `WindowSignature.compute(from:)` for Ken's future public Core Graphics window-list signal collection and a `TODO.M2` marker where SpaceDetection will wire those signals.
- Implemented matching in `JSONFileSpaceNameStore`: exact signal match first, then same-display Jaccard window overlap at ≥70%, preserving `firstSeen` while refreshing volatile signals; no same-display fuzzy match returns nil so callers can treat it as a new Space.
- Fixed real compile blockers surfaced after the toolchain reached source compilation: `OverlayWindow` now calls the designated `NSWindow` initializer, and the app delegate creation is main-actor-safe from top-level `main.swift`.
- Verification: `swift build` completed successfully; `swift test` completed successfully with 7 tests passing and 0 failures.

### Ken's Window-List Strategy Validation (2026-05-10T19:14:32Z)
- **Ken completed probe research:** All 5 identity probes built and ran successfully. Key finding: use `[.optionOnScreenOnly, .excludeDesktopElements]` + layer-0 filter for window signatures (Core Graphics window-list collection).
- **Notifications need debouncing:** Ken flagged that raw `NSWorkspace` notifications need debouncing before updating persistence.
- **Action for SpaceDetection wiring:** When implementing `WindowSignature.compute(from:)`, wire Ken's recommended window-list strategy and add debounce buffer.
- **Probes 3 & 5 flagged:** Manual re-runs needed for Space-switch and fullscreen/hotplug edge cases; defer until after M1 shipping if time-boxed.

### Watermark Positioning (2026-05-10T15:28:19.948-04:00)
- Added `WatermarkPosition` in `OverlayRenderer` with `.lowerRight`, `.lowerLeft`, `.upperRight`, `.upperLeft`, and `.center`.
- `WatermarkView` now takes a position and maps it through SwiftUI `Alignment`; `OverlayController` owns the default so all per-screen overlays update from one code path.
- Default remains `.lowerRight`, but corner padding is now 80pt horizontal and 60pt vertical; this keeps the ambient label off the hard screen edge and away from Dock/menu-bar pressure.
- Layout quirk: `OverlayWindow` already sizes to `NSScreen.visibleFrame`, so AppKit handles menu bar/Dock safe area first; SwiftUI padding is applied inside that visible frame.


### Watermark Hover-Flee (2026-05-10T15:30:14.156-04:00)
- Implemented hover-flee in `OverlayRenderer` with a single `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` owned by `OverlayController`; this preserves `ignoresMouseEvents = true` and keeps overlay windows click-through.
- Added `WatermarkHoverFleeState`: each overlay starts at the configured `WatermarkPosition`, flees to `configuredPosition.diagonalOpposite` on hover, stays put on hover-out, and toggles back if hovered again at the opposite position. Center maps to center, so it does not flee in v1.
- Throttled global mouse sampling to 30 Hz with a 33ms interval and cached inside/outside state per display so steady mouse movement inside or outside the same watermark does not re-run the state machine.
- `NSEvent.addGlobalMonitorForEvents` reports mouse moves outside this app, which is exactly what click-through overlay windows need; use `NSEvent.mouseLocation` for current global coordinates and hop back to the main queue before touching AppKit/SwiftUI state.
- Animation is a boring 0.25s SwiftUI ease-in-out on the watermark position; the full-screen overlay window itself never moves.

### M2 Space Naming Loop (2026-05-10T15:43:36.730-04:00)
- Added `SpaceFingerprinter` in `Sources/SpaceDetection/SpaceFingerprinter.swift`; it owns public Core Graphics display UUID collection, Ken's window-list recipe (`.optionOnScreenOnly` + `.excludeDesktopElements`, layer-0 app windows), stable `bundleID:title` tokens, SHA-256 16-hex diagnostics, and the simple per-display ordinal counter.
- Debounced `NSWorkspaceSpaceDetector` notifications at 250ms, last-write-wins, before collecting snapshots and matching persistence.
- Replaced the M1 stub path with `OptionClickRenameController` in `Interaction`: global + local Option `flagsChanged` monitors temporarily disable click-through, watermark taps enter inline rename, Enter saves, Escape/outside click cancels.
- `OverlayController` now has a rename mode that temporarily allows key windows/mouse events and swaps the watermark for a focused SwiftUI `TextField` at 35% opacity.
- Added a tiny status bar item using `rectangle.dashed`, with “Rename current Space…” sharing the same rename path and “Quit Virtual Overlay”.
- Tricky bit: text editing requires the overlay window to temporarily become key; display mode returns to click-through unless Option is still held.
- Verification: `swift build && swift test` passed with 13 tests, 0 failures.

### Option Suspends Hover-Flee (2026-05-10T15:50:52.457-04:00)
- Option now means “interact with the watermark,” so hover-flee is suspended while Option is held and resumes from the watermark’s current position when released.
- Rename targeting must use the watermark’s current on-screen bounds/current rendered position, including the fled position, not the configured home position.
- Verification: `swift build && swift test` passed with 14 tests, 0 failures.

### Space Switch Lag Removed (2026-05-10T15:58:36.087-04:00)
- Dropped the 250ms Space-change debounce entirely instead of replacing it with a smaller coalescing delay.
- Reason: the current path is cheap enough—one notification-triggered fingerprint plus a store lookup—and the code did not show a proven 10+ Hz storm requirement that justifies user-visible latency.
- New contract: a Space-change notification emits immediately on the main actor, and the overlay text source applies a stored-name update within one main-actor tick; duplicate notifications are deduped at output by no-oping when the resolved name already matches the displayed watermark.
- Rendering rule: watermark text changes snap, position changes animate.
- Verification: `swift build && swift test` passed with 15 tests, 0 failures after the change.

### Space Identity v1.1 Collision Fix (2026-05-10T16:06:03.295-04:00)
- Strengthened the Space fingerprint shape to include `displayUUID`, `windowSignature`, `frontmostAppBundleID`, separate `windowCount`, `windowGeometrySignature`, `ordinal`, and `firstSeen`.
- Tightened the matcher contract: exact signal equality wins; fuzzy matching now requires same display, same frontmost app, at least 0.8 Jaccard similarity over visible window bundle IDs, and a 0.15 winner margin over the runner-up. Ambiguity returns nil instead of guessing.
- Migration behavior: pre-v1.1 JSON entries still decode with defaulted new fields, but richer current fingerprints normally will not fuzzy-match them. Those old mappings become harmless orphans and users re-create labels via Option-click rename.
- Verification: `swift build && swift test` built successfully; the final `swift test` pass completed with 18 tests, 0 failures.

### Space Identity v1.2 CGS Session Anchor (2026-05-10T16:15:05.647-04:00)
- Added runtime `dlsym` resolution for private Core Graphics Services symbols in `CGSPrivate.swift`: `CGSMainConnectionID` and `CGSGetActiveSpace`, loaded from CoreGraphics with no link-time private-framework dependency; the symbols are cast as `@convention(c)` function pointers to match the C ABI.
- Fallback chain: if CoreGraphics cannot be opened, either symbol is unavailable, or `CGSGetActiveSpace` returns 0, the fingerprinter logs to stderr and continues with the existing public fingerprint; the app should not crash on missing private symbols.
- `SpaceIdentity` now carries optional `cgsSpaceID`; when current and stored identities both have CGS IDs, exact CGS equality is authoritative and heuristic fields are ignored. When CGS is nil, matching falls back to the v1.1 exact/fuzzy heuristic.
- Re-bind-on-launch behavior: `JSONFileSpaceNameStore` clears persisted CGS IDs in memory on load because Alan confirmed they are not reboot-stable. First revisit after launch matches by heuristic fingerprint, refreshes the entry with the fresh session CGS ID, and preserves the user name.
- Migration UX: existing entries may show `UNNAMED` until Cristian visits/renames enough Spaces for re-binding; after a Space is re-bound, names are rock-solid for that login session.
- Verification: baseline `swift build && swift test` passed with 18 tests, 0 failures; after v1.2, `swift build && swift test` passed with 21 tests, 0 failures.

### Re-bind Removal and Fresh Rename Identity (2026-05-10T16:28:42.833-04:00)
- Removed the Don-8 re-bind behavior that let heuristic-only stored entries (`cgsSpaceID = nil`) attach themselves to a fresh session CGS Space ID. Those entries now stay dormant/orphaned instead of poisoning current Space identities; users rename Spaces once under the CGS identity scheme.
- Added the rename invariant: submit/Enter captures the current Space identity fresh at commit time through the same `SpaceFingerprinter.currentIdentity()` path used by display refresh, then writes the name to that exact identity.
- Read/write drift audit found real drift in the rename path: `OptionClickRenameController` captured the identity at rename start and reused it on commit. The stale re-bind bug was the likely visible cause of “second always shows third,” but the stale commit capture was also present and is now fixed.
- Verification: baseline `swift build && swift test` passed with 21 tests, 0 failures; after fixes, `swift build && swift test` passed with 24 tests, 0 failures.

### Git Repository Initialization (2026-05-10T16:50:55.842-04:00)
- **Status:** Repository initialized at `/Users/cristianormazabal/Projects/virtual-overlay-for-mac` with default branch `main`.
- **Commit SHA:** `9e92653` (Initial commit — Virtual Overlay M2).
- **Tracked files:** 213 files committed, 22128 insertions. Includes all source code, tests, .gitattributes, .copilot/, GitHub workflows, and **full .squad/ team memory** (decisions, agent histories, orchestration logs, research artifacts, probes). Prototypes folder preserved for historical reference.
- **Ignored paths:** `.build/`, `.swiftpm/`, `DerivedData/`, `*.xcuserdata/`, `*.xcworkspace/xcuserdata/`, `.DS_Store`, `.AppleDouble`, `Icon?`, `.vscode/`, `.idea/`, `.swp`, `*~`, `.squad-workstream` (local machine activation).
- **Gitattributes preserved:** `.squad/decisions.md` and `.squad/agents/*/history.md` configured for `merge=union` to avoid conflicts on append-only team state.
- **Working tree clean:** `git status` shows no staged, unstaged, or untracked files. Repository ready for remote addition.
- **Note:** No remote configured yet; Cristian will add one if needed.

### Multi-Display CGS Per-Display Lookup Correction (2026-05-10T17:18:00.082-04:00) — Ken's Fix
- **Status:** Don was locked out of this revision per reviewer-rejection-lockout pattern (Ken handled Ken's earlier probe assignments). Ken diagnosed and corrected the implementation.
- **The bug:** Your v1.2 implementation used `CGSGetActiveSpace(connection)` for Space identity, which is global to the keyboard-focused display, not per-display. Cristian's multi-display setup showed all overlays with the same name because every display resolved to the focused display's Space ID.
- **The fix:** Ken implemented per-display `CGSManagedDisplayGetCurrentSpace(connection, displayUUID)` for each overlay's NSScreen. The fallback chain is: per-display symbol → global CGS → public heuristic, each tier logging diagnostics.
- **Your v1.2 strategy was correct** (private CGS for session-scoped disambiguation); the implementation detail (global vs per-display symbol) was wrong. The CGS matching logic you wrote remains intact; the symbol resolution now correctly uses the per-display alias.
- **Verification:** All 27 tests pass, 0 failures. Regression tests added with GOTCHA comment at call site.
- **Decision:** Ken's correction supersedes the CGS symbol detail in Decision 3 (v1.2). Strategy stays; implementation changes to per-display.
