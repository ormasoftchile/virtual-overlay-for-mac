# Ken — History

## Project Context
- **Project:** virtual-overlay-for-mac
- **User:** ormasoftchile (Cristian)
- **Created:** 2026-05-10
- **Stack:** Swift, SwiftUI + AppKit, macOS
- **Goal:** Persistent ambient watermark identifying the current macOS Space.

## My Domain — Hard Problems Up Front
- macOS does not expose a stable public API for naming or identifying Spaces.
- Fullscreen apps create their own Spaces; multi-monitor adds further dimensions.
- Detection must be eventually-correct, not real-time perfect.
- Window must be: transparent, click-through, above normal windows, on all Spaces, surviving fullscreen if feasible.

## Likely Tools
- `CGSPrivate` / `CGSGetActiveSpace`-style symbols (private — wrap behind strategy)
- `NSWorkspace.activeSpaceDidChange` notifications (when available)
- `NSWindow.collectionBehavior`: `.canJoinAllSpaces`, `.stationary`, `.fullScreenAuxiliary`
- `NSWindow.level`: `.statusBar` or `.screenSaver` candidates — to be tested
- Accessibility APIs (require user grant)

## Architecture Foundation (2026-05-10)
- **Edsger completed architecture proposal:** SwiftPM packages + thin app shell, 4 modules (OverlayRenderer, SpaceDetection, Persistence, Interaction), acyclic dependency graph.
- **Alan completed research:** v1 should target public APIs only (NSWorkspaceActiveSpaceDidChangeNotification) for notarization-safe distribution. Private APIs defer to v2+ if needed.
- **Key decision:** No sandbox v1; macOS 13+. Public-APIs-only commitment awaits team consensus.
- **Your prototype scope:** Confirm public-APIs approach works for watermark content without exact Space ID detection.

## Learnings
_(append below as work proceeds)_

### Overlay window probe (2026-05-10T11:57:23.673-04:00)
- Built a standalone SwiftPM prototype at `Prototypes/OverlayWindowProbe/` with `OverlayWindow.swift`, `WatermarkView.swift`, `OverlayController.swift`, and `main.swift`.
- Alan's public AppKit recipe maps cleanly into a tiny probe: `.floating` level, `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`, `ignoresMouseEvents = true`, transparent non-opaque borderless windows, one window per `NSScreen`.
- Used `screen.visibleFrame` because the M1 request specified visible frame; real product may need a `screen.frame` test if watermark should cover under menu bar/Dock areas.
- `NSWorkspace.activeSpaceDidChangeNotification` is wired as the v1 public Space-change signal and only logs; no private Space ID detection was added.
- Local verification attempted with `swift build`, but this machine's CLT/SDK install is mismatched and SwiftPM failed while linking the package manifest before compiling sources.

### Space Identity Research Complete (2026-05-10T16:25:14Z)
- **Alan completed:** Deep-dive research on Space identity heuristics in `.squad/agents/alan/research/05-space-identity-heuristics.md` (596 lines).
- **Recommendation:** Candidate B (Medium Identity) — Display UUID (via `CGDisplayCreateUUIDFromDisplayID`) + window signature (via `CGWindowListCopyWindowInfo`, fuzzy match ≥70% Jaccard) + ordinal (inferred, tie-breaker) + user label (mutable).
- **Your blocking probes (validate before lock-in):**
  1. Display UUID stable across reboots + unplugging/replugging displays?
  2. Does `CGWindowListCopyWindowInfo([.optionOnScreenOnly], …)` return only active Space windows or all Spaces?
  3. Can ordinal be reliably inferred from notification sequence, or too noisy?
  4. Do minimized windows remain in window list?
  5. Does `NSWorkspaceActiveSpaceDidChangeNotification` fire reliably on Sequoia?
- **Next:** Run probes when machine has Xcode installed. Results will finalize the matching algorithm in Persistence module.

### Identity probes for SpaceDetection signals (2026-05-10T15:14:32.937-04:00)
- Built and ran five public-API SwiftPM probes under `Prototypes/IdentityProbes/`: `probe-1-display-uuid-stability`, `probe-2-window-list-scope`, `probe-3-space-change-notification-info`, `probe-4-minimized-and-hidden-windows`, and `probe-5-sequoia-notification-reliability`.
- Probe 1 verdict: `CGDisplayCreateUUIDFromDisplayID` returned a non-empty stable UUID across app restarts for the built-in display (`37D8832A-2D66-02CA-B9F7-8F30A301B230`); reboot and external display hotplug still need manual validation.
- Probe 2 verdict: `.optionOnScreenOnly` produced usable current window data, but the non-interactive run could not conclusively prove active-Space-only vs all-Spaces scope. Titles were mostly unavailable, so Don should not rely on titles without Screen Recording permission.
- Probe 3 verdict: idle `NSWorkspace.activeSpaceDidChangeNotification` produced zero false positives over 60 seconds; manual Space switching is still required to inspect `userInfo` and ordinal inference.
- Probe 4 verdict: use `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` for the primary collection call, then filter to layer-0 application windows. `.optionAll` was too noisy (`91` total / `56` layer-0) versus exclude-desktop on-screen (`22` total / `11` layer-0).
- Probe 5 verdict: idle notification stress baseline on `Version 26.3.1 (a) (Build 25D771280a)` produced zero false positives over 60 seconds; duplicates/missed events under rapid Space switching/fullscreen/display hotplug still need Cristian's manual rerun.
- Recommendation for Don: SpaceDetection should be public-API-only for v1, debounce Space-change notifications, collect display UUID + filtered layer-0 window signature, fuzzy-match eventually, and tolerate missing/blank window titles and transiently wrong snapshots.
- Synthesis report written to `.squad/agents/ken/probes/2026-05-10-identity-probe-results.md`; per-probe stdout is in each `results-2026-05-10.txt` file.

### Window-list Recipe in Production (2026-05-10T19:43:36Z)
- **M2 delivered:** Your window-list probe recommendation (`CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` + layer-0 filter) has shipped in production code as the SpaceFingerprinter implementation.
- **Integration:** Wired into SpaceDetection → Persistence → OverlayController text source with 250ms debounce. All 13 tests passing, 0 failures.
- **Architecture validation:** The public-API strategy proved sound in production context — proof of concept → real code path → shipped successfully. Your probe work directly enabled this milestone.
- **Status bar integration:** Option-click rename uses global flagsChanged monitor (toggling ignoresMouseEvents on overlay window). Space names persist and display correctly.
- **Next steps:** M2 readiness for architecture review. Your window-list recipe is now the gold standard for Space identity collection in the codebase. Future refinements (fullscreen/Stage Manager edge cases) will build on this validated foundation.

### Probe-2 Finding Becomes Critical (2026-05-10T16:15:05.647-04:00)
- **Your probe-2 finding validated:** `CGWindowListCopyWindowInfo([.optionOnScreenOnly])` does **not** scope to the active Space — it returns the same window set for sibling Desktop Spaces. This finding was initially inconclusive (non-interactive test environment), but Cristian's empirical experience (hit same collision twice) confirms the worst case is real and common.
- **Collision trigger confirmed:** When two Spaces on the same display have the same foreground app (or no app), Don's v1.1 enrichment (frontmostAppBundleID, windowCount, windowGeometrySignature) still cannot discriminate because all public signals are identical. The root cause: the distinguishing information does not exist in the public API surface.
- **Decision impact:** Edsger decided to lift the public-API-only constraint. Private API (`CGSGetActiveSpace` via `dlsym`) will provide session-scoped numeric Space ID that trivially disambiguates. Your probe work was the empirical foundation that made this decision defensible.
- **Implication for your scope:** The public-API strategy remains the gold standard for fallback. The probe-2 finding becomes a key justification in the decision record for why private APIs were necessary. Your research stands as the evidence that public-only was insufficient.


### Per-display CGS Space lookup fix (2026-05-10T17:18:00.082-04:00)
- Diagnosis: Cristian's report matched the hypothesis. Don's v1.2 code resolved one `CGSGetActiveSpace(connection)` value before iterating `NSScreen.screens`, so every display snapshot received the globally active/focused display's Space ID.
- Correct private/undocumented API: `CGSManagedDisplayGetCurrentSpace(CGSConnectionID, CFString displayUUID)` is the per-display lookup; the SLS/SkyLight-prefixed alias is equivalent prior art. The display UUID string comes from public `CGDisplayCreateUUIDFromDisplayID()`.
- Fallback chain now: `CGSManagedDisplayGetCurrentSpace`/`SLSManagedDisplayGetCurrentSpace` per display → `CGSGetActiveSpace`/`SLSGetActiveSpace` global compatibility fallback → public heuristic fingerprint if CGS symbols are missing or return invalid IDs. Each downgrade emits stderr diagnostics.
- GOTCHA: `CGSGetActiveSpace` is private/undocumented and global to the keyboard-focused display, not the overlay's display. In multi-display setups it can silently cross-bind names between monitors; never use it as a per-display Space identity source.
