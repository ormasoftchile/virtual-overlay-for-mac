# Don — History

## Current Focus: Release Pipeline & Distribution

### Release Pipeline (2026-05-10T19:54:52.490-04:00)
- Use `ditto -c -k --keepParent` instead of plain `zip` for `.app` bundles; app bundles are directory trees with macOS metadata/resource-fork/symlink edge cases, and `ditto` is the correct preservation tool.
- Added the ad-hoc release pipeline pattern: local `ship.sh VERSION` runs tests, builds the app bundle, verifies the ad-hoc signature, clears xattrs, emits a GitHub Release ZIP plus SHA-256 sidecar, and prints the `gh release create` command without publishing.
- Versioning stays in the produced bundle/artifacts only; committed source files do not carry release bumps.
- **Verification:** `./ship.sh 0.1.0-rc1 --allow-dirty` runs tests (33 passing), builds dist/Virtual Overlay.app, generates ZIP + SHA-256, and prints manual release command.

### Distribution Decision (2026-05-10T19:54:52.490-04:00) — RATIFIED
- **Decision 13: Release Pipeline — ship.sh is Canonical Local Path**
- Tier 1 (ad-hoc signed, GitHub Releases) is viable and proven for power-user tools (Yabai, Hammerspoon, Übersicht precedent).
- Notarization not possible due to private API usage (`CGSGetActiveSpace`, `CGSManagedDisplayGetCurrentSpace`); refactoring for v2+ if user feedback demands frictionless distribution.
- **Next:** Cristian creates first GitHub Release with ZIP + SHA-256; announce to audience.

## M1–M2 Summary (From Archive)

**Completed Work:**

1. **SwiftPM Scaffold:** Four library modules (OverlayRenderer, SpaceDetection, Persistence, Interaction), app target, Ken's overlay recipe, SwiftUI watermark.
2. **Space Identity (v1.1 + v1.2):** Candidate B fingerprinting → enriched collision fix → CGS session anchor (corrected to per-display by Ken).
3. **Option-Click Rename:** Inline text editing, status bar menu, fresh identity capture on save.
4. **Watermark Positioning & Hover-Flee:** Corner picker, diagonal flee on hover, 30 Hz sampling.
5. **Preferences Window:** Color picker, font size slider, position grid, live preview with 500ms debounce, observable sync.
6. **Watermark Preferences v1/v2/v3:** Initial schema → opacity split → curated font family (SF Pro, SF Mono, New York, Helvetica Neue, Menlo).
7. **Test Coverage:** Scaled from 7 → 33 tests (all passing).

**Decisions Locked:** Project shape, module boundaries, distribution tier, release pipeline, preferences, identity algorithm, icon design.

**Repository Status:** 213 files committed (22128 insertions), clean working tree, full .squad/ team memory preserved.

---

## Prior Sessions
See `history-archive.md` for M1 detailed progression (through 2026-05-10T19:32:38).
