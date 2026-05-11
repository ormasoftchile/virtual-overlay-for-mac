# Don — History Archive

This archive preserves Don's early implementation work from 2026-05-10 (up to T19:32:38). For the current session, see `history.md`.

## Summary

Don engineered the entire Virtual Overlay v1 stack from architecture-locked scaffold to full-featured app in one day:

1. **SwiftPM Scaffold (M1 foundation):** Root `Package.swift`, four library modules (`OverlayRenderer`, `SpaceDetection`, `Persistence`, `Interaction`), and app target. Ported Ken's overlay recipe; added SwiftUI watermark, public-API Space detection, and JSON persistence.

2. **Space Identity Algorithm (M2 core):** Implemented Alan's Candidate B fingerprinting (display UUID, window signature, ordinal). Added heuristic exact/fuzzy matching at ≥70% Jaccard window overlap. Debounced notifications, re-bind behavior, and fresh rename capture.

3. **v1.1 Collision Fix:** Enriched fingerprint (frontmost app, window count, geometry). Tightened matcher to require same display + high window overlap + no ambiguity. Migration preserves old JSON; users re-assign names via Option-click.

4. **v1.2 CGS Session Anchor:** Added runtime `dlsym` for `CGSGetActiveSpace`. Optional `cgsSpaceID` on `SpaceIdentity`. Session-scoped CGS lookup authoritative when available; fallback to heuristic fingerprint. Clear CGS IDs on app launch (non-reboot-stable).

5. **Option-Click Rename (M2 feature):** Global + local Option `flagsChanged` monitors. Inline text editing in place of watermark. Persist fresh identity on Enter; Escape cancels. Status bar menu with quit & rename shortcuts.

6. **Watermark Positioning & Hover-Flee:** Corner picker (upper/lower left/right). Hover-flee inverts to diagonal opposite, remembers state per hover cycle. 30 Hz throttled mouse sampling; 0.25s animation.

7. **Preferences Window (M2 enhancement):** Dedicated JSON store separate from Space names. `WatermarkAppearance` observable shared between Preferences UI and OverlayController. Color picker + 6 curated swatches, font size slider, position grid. 500ms debounce for disk writes; live preview applies full snapshot atomically.

8. **v3 Watermark Preferences:** Separated opacity from color. Added curated font family selector (SF Pro, SF Mono, New York, Helvetica Neue, Menlo). Migration backward-compatible.

9. **Release Pipeline:** `ship.sh` orchestration: tests → app build → signature verify → ditto ZIP + SHA-256 + RELEASE_NOTES stub. Prints `gh release create` command for manual publish. No CI signing.

## Test Progression

- Initial scaffold: 7 tests ✓
- After Candidate B identity: 18 tests ✓
- After v1.2 CGS: 21 tests ✓
- After rename + hover-flee: 24 tests ✓
- After preferences v2/v3: 32 tests ✓
- Final bundle validation: `./ship.sh 0.1.0-rc1 --allow-dirty` → 33 tests ✓

## Decision Trail

- **Decision 1:** Project Shape & Module Boundaries (Edsger, locked)
- **Decision 2:** v1 Distribution (public APIs only, locked then SUPERSEDED)
- **Decision 3:** v1.2 CGS Lift (Edsger, SUPERSEDED by Ken's per-display fix)
- **Decision 4:** Per-display CGS Correction (Ken, final)
- **Decision 5:** Programmatic Icon (Susan, approved)
- **Decision 6:** Preferences v1 (Don, approved)
- **Decision 7–11:** Preferences v2/v3, Hover-state, etc. (Don, all proposed/approved)

## Git Commit

Baseline repository initialized 2026-05-10T16:50:55 (9e92653) with all source + full .squad/ team memory (213 files, 22128 insertions). Repository clean and ready for distribution pipeline commit.

---

Archive cut at 2026-05-10T19:32:38 (end of Watermark Font Family Selector implementation). Subsequent updates in `history.md` cover Release Pipeline and distribution decisions.

