# Edsger — History

## Project Context
- **Project:** virtual-overlay-for-mac
- **User:** ormasoftchile (Cristian)
- **Created:** 2026-05-10
- **Stack:** Swift, SwiftUI + AppKit integration, macOS native
- **Goal:** Persistent ambient watermark identifying the current macOS Space, so users (and audiences during demos) always know which environment they are in.

## Product Pillars
- Persistent text-only watermark (~5–12% opacity, large, restrained typography)
- Logical naming of Spaces (PRODUCTION, DEMO, CODING, ONCALL)
- Option-click watermark to rename inline
- Eventually-correct active Space detection
- Multi-monitor support, click-through, fullscreen-tolerant where feasible

## Architectural Goals
Clean separation between four modules:
1. **Overlay renderer** — transparent NSWindow, click-through, multi-display
2. **Space detection engine** — pluggable strategies, eventually-correct
3. **Persistence layer** — local JSON/store of `space-uuid → name`
4. **Interaction layer** — Option-click rename, hotkeys

## Out of Scope (v1)
Window management, Mission Control automation, layout restoration, tiling.

## Learnings

### 2026-05-10 — Architecture v1 Proposal
- **Project shape:** SwiftPM-based modules + thin Xcode app shell. Pure `.xcodeproj` offers no real module boundary enforcement; pure SwiftPM can't carry a macOS bundle. The hybrid is the only option that satisfies all constraints (testability, boundaries, bundle needs).
- **Module dependency graph:** `App → Interaction → {OverlayRenderer, SpaceDetection, Persistence}`. Persistence imports SpaceDetection only for the `SpaceID` value type. No cycles.
- **Sandbox trade-off:** Deliberately shipping v1 without sandbox to avoid blocking private API usage for Space detection. This blocks MAS distribution but is acceptable for local-only v1.
- **Minimum deployment target:** macOS 13 (Ventura) — balances modern SwiftUI features with `CGSCopyManagedDisplaySpaces` availability.
- **M1 strategy:** Hardcode everything except the overlay rendering. Validates the NSWindow + SwiftUI + LSUIElement + multi-monitor stack before adding real detection/persistence complexity.

### 2026-05-10 — v1 Public-API-Only Ratification
- **Decision ratified:** v1 uses only public macOS APIs. `NSWorkspace.activeSpaceDidChangeNotification` is the sole Space-change signal. Private CGS/SkyLight symbols (`CGSGetActiveSpace`, `CGSCopySpaces`, `CGSCopyManagedDisplaySpaces`) are explicitly out of scope for v1.
- **Space-identity trade-off accepted:** No stable, persistent Space identifier exists on macOS — not even via private APIs. v1 treats Space identity as ordinal/heuristic, session-scoped. Persistence schema documents this honestly. User-assigned names may become orphaned after reboot or Space reorder. Acceptable for v1; user can re-assign in seconds.
- **Sandbox rationale updated:** We still skip sandbox in v1, but the reason is now simplicity, not private API access. Hardened runtime is compatible and can be enabled for notarization whenever we want.
- **Constraints placed on team:**
  - **Ken:** Detection strategies must NOT import private CGS symbols. Only the public-API strategy ships in v1. The `SpaceDetectionStrategy` protocol stays as the v2 extension point.
  - **Don:** Persistence schema must use the heuristic identifier from the public-API strategy and document its limitations in code (session-scoped, not stable across reboots).
  - **Alan:** Continue tracking private-API alternatives for v2 research corpus. Do not gate v1 on them.
- **Key insight from Alan's research:** Even private CGS UUIDs don't persist across reboots or Mission Control modifications, so private APIs don't actually solve the persistence problem. This made the public-API-only decision easier — we're not giving up real persistence capability, because it doesn't exist at any API level.

### 2026-05-10 — Build Green and Toolchain Healthy (2026-05-10T19:14:32Z)
- **Don's refactor complete:** SwiftPM build and test suite now fully green (swift build && swift test pass; 7 tests, 0 failures).
- **Toolchain status:** All compile blockers resolved. LSUIElement code path functional via `NSApp.setActivationPolicy(.accessory)`. Identity refactored to Candidate B per Alan's spec and validated in tests.
- **Ken's probe validation:** All 5 identity probes built and ran successfully. Window-list strategy validated: `[.optionOnScreenOnly, .excludeDesktopElements]` + layer-0 filter recommended. Notifications need debouncing.
- **M1 milestone readiness:** Build unblocked. Public-API approach validated end-to-end. Team ready to move from M1 scaffolding to integration features (Option-click rename, hotkey bindings, multi-monitor refinement).

### 2026-05-10 — M2 Naming Loop Complete (2026-05-10T19:43:36Z)
- **M2 milestone delivered:** Space identity loop + rename interaction + status bar UI functionally complete. SpaceFingerprinter (displayUUID + window-set hash + ordinal) wired end-to-end through SpaceDetection → Persistence → OverlayController with 250ms debounce.
- **Option-click rename:** Global flagsChanged monitor toggles overlay clickability while Option held. Escape and blur/outside click cancel; Enter saves.
- **Status bar UI:** NSStatusItem provides "Rename current Space" and "Quit" affordances.
- **Test coverage:** 13 tests, 0 failures.
- **Architecture note:** Private API surfaces isolated behind Ken's interfaces; no direct private imports in product code. Public-API approach validated in production code path.
- **Next phase readiness:** M2 establishes the real-world naming loop UX. Architecture review can proceed with confidence that the identity/persistence/interaction contract is sound. M3 (hotkeys, multi-monitor refinement) can proceed in parallel with M2 stabilization.

### 2026-05-10 — Space Identity Reckoning (v1.2 Decision)
- **Decision:** Lifted the public-API-only constraint for Space identity. `CGSGetActiveSpace` (resolved via `dlsym` at runtime) will provide a session-scoped numeric Space ID that trivially disambiguates sibling Spaces on the same display. Supersedes both my v1 public-API-only ratification and Don's v1.1 enriched fingerprint decision.
- **What failed:** Public APIs cannot distinguish two Desktop-style Spaces with similar visible state. `CGWindowListCopyWindowInfo([.optionOnScreenOnly])` does not scope to the active Space — it returns the same window set for sibling Spaces. Cristian hit this collision class twice: once with the original fingerprint, again after Don's v1.1 enrichment (frontmostApp, windowCount, geometryHash). No combination of public signals solves this because the distinguishing information simply doesn't exist in the public API surface.
- **Why Path A over B/C:** Path B (UX-only: show UNNAMED on ambiguity) doesn't work when every Space produces the same fingerprint — every visit shows UNNAMED and renames overwrite each other. Path C (session-local visit-order tracking) is fragile across return visits. Path A uses the actual Space ID the OS knows internally, isolated behind `dlsym` + nil-checks with automatic fallback.
- **Implementation guidance for Don:** Add `cgsSpaceID: UInt64?` to `SpaceIdentity`. Create `CGSPrivate.swift` with runtime `dlsym` resolution of `CGSMainConnectionID` and `CGSGetActiveSpace`. Populate the CGS ID in `SpaceFingerprinter.currentSnapshots()`. Add CGS exact-match as highest-priority path in `JSONFileSpaceNameStore.match()`. Invalidate stale CGS IDs on app launch (they don't survive reboots). Retain all existing public-API and UNNAMED fallback paths unchanged. Full spec in `.squad/decisions/inbox/edsger-space-identity-v1.2.md`.

### 2026-05-10 — Version Control & Distribution Infrastructure (v1 Complete)
- **Don-10 (Git Init):** Repository initialized, `.gitignore` strategy established. `.squad/` directory preserved for decision records. 2 baseline commits on main. No remote configured (local-only v1 workflow).
- **Don-11 (App Bundle):** `bundle.sh` script completed — wraps SwiftPM release build into signed, deployable `.app`. Bundle identifier: `com.ormasoftchile.virtualoverlay`. Produces `dist/Virtual Overlay.app/` with LSUIElement = true in Info.plist. Version: 0.1.0 / build 1. Minimum macOS: 13.0 (matching `Package.swift`).
- **Signing Trade-off (v1):** Ad-hoc signing (`codesign --sign -`) is in effect. Meets Gatekeeper requirements for local execution and subprocess launching. Does not require macOS Developer certificate or provisioning profile. Failures are warnings, not blockers. v2 can replace with certificate signing orthogonally.
- **Unblocked:** Reproducible, scriptable builds for CI/CD pipelines. End-user deployment without Xcode. Path to notarization and App Store in v2 (certificate signing upgrade, bundle.sh structure unchanged).

### 2026-05-10 — Multi-Display CGS Implementation Correction (Ken-2)
- **Status:** Ken's revision (Don locked out per reviewer-lockout protocol). Decision 4 now supersedes your v1.2 implementation detail.
- **Your v1.2 strategy was correct:** Lifting public-API-only constraint for session-scoped Space disambiguation via private CGS was the right call. The evidence (Ken's probe work) was solid; the rationale was sound.
- **The implementation detail was wrong:** You implemented with global `CGSGetActiveSpace`, but Cristian's multi-display setup revealed it's keyboard-focused-display only. Ken corrected to per-display `CGSManagedDisplayGetCurrentSpace(connection, displayUUID)`.
- **The fix preserves your logic:** CGS matching order and the full fallback chain you specified remain intact. Only the symbol changes from global to per-display. All 27 tests pass, 0 failures.
- **Decision impact:** Decision 3 (your v1.2) rationale stands unchanged. Decision 4 (Ken's correction) refines the implementation detail (CGS symbol choice). The architectural choice (private CGS for session-scoped ID) and the strategy-pattern architecture were proven sound by Don's clean implementation.

### 2026-05-10 — Visual Identity Established (Susan, Designer)
- **Team growth:** Designer position filled. Susan joined and shipped programmatic app icon in first session.
- **Icon design:** Typographic mark—SF Pro ultra-light `[V]` framed by geometric bracket rules on near-black squircle. Echoes the product's ambient, infrastructural aesthetic (Bloomberg terminal labels, NYC subway signage, architectural marking systems).
- **Implementation:** Source-of-truth in code (`Tools/IconGenerator/`, Swift CLI using Core Graphics / AppKit), not design-tool binary. Outputs all PNG sizes + `.icns`, checked in at `Resources/`.
- **Bundle integration:** `bundle.sh` copies icon to app bundle and sets `CFBundleIconFile`. No Xcode project changes needed; design assets remain orthogonal to build.
- **Decision 5:** Approved in `.squad/decisions.md`. v1 visual identity foundation locked; future assets (status bar glyph, etc.) will follow the same restrained, infrastructural aesthetic.
- **Team impact:** Team size 4 → 5. Visual review authority established for future assets.

