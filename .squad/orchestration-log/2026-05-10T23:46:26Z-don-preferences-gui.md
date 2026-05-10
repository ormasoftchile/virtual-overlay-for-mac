# Orchestration: Preferences GUI Polish (Don Tasks 13–16)

**Session timestamp:** 2026-05-10T23:46:26Z  
**Conductor:** Scribe  
**Requested by:** ormasoftchile  

## Summary

Four focused don tasks implementing Preferences UI refinements and decoupling. All tasks completed with 33 tests passing and clean bundle.sh output.

## Task Manifest

### don-13: Explicit Opacity Slider
- Added separate `opacity: Double` field to `WatermarkPreferences` v2
- Decoupled from Color alpha; Color alpha normalized to `1.0`
- v2 prefs migration: reads v1 `color.alpha` → new `opacity`, saves v2 schema
- Preferences UI exposes opacity as 1%…100% slider

### don-14: Live Label Updates
- Bound slider labels to live `@State` value during drag, not debounced observable
- Fixes label jitter and stale display while slider moves
- Applies to Opacity, Font Size sliders
- Label updates immediately; debounce covers disk writes only

### don-15: Watermark Position-Reset Bug
- Live preview now applies full `WatermarkPreferences` snapshot (whole-draft)
- Hover-flee home state preserved across cosmetic changes (opacity, font, color)
- Position reset suspended unless `position` field actually changes
- 500ms debounce governs disk writes; not part of preview data path

### don-16: Font Family Picker
- Added curated `WatermarkFontFamily` enum: SF Pro, SF Mono, New York, Helvetica Neue, Menlo
- Implemented `fontFamily` selector in Preferences UI
- v3 prefs migration: defaults new entries to `.sfPro`
- No full system picker or user-installed fonts

## Decisions Archived

The following proposals were added to `decisions.md` during this session:

- **Decision 7:** WatermarkPreferences v2 — Color and Opacity Split
- **Decision 8:** WatermarkPreferences v3 — Curated Font Family
- **Decision 9:** Live Preview Uses Complete Preference Snapshots
- **Decision 10:** Live State Owns Slider Labels
- **Decision 11:** Retire Heuristic CGS Re-bind
- **Decision 12:** SwiftPM App Bundle Script

Note: Decision 4 (Per-display CGS) and Decision 5 (Programmatic App Icon) were already in decisions.md; the corresponding inbox entries were deduplicated and discarded.

## Quality Metrics

- **Tests:** 33 passing, 0 failures
- **Bundle:** `./bundle.sh` produces clean artifact at `dist/Virtual Overlay.app`
- **Migrations:** v1 → v2 → v3 chain validated with existing user data
- **Code coverage:** Preferences window, live sliders, position reset, font family selection

## Implementation Notes

- All preference mutations flow through single `WatermarkPreferences` draft for consistency
- Debounce (500ms) isolated to disk I/O; preview updates are immediate and complete
- Font enum bounded to 5 curated faces; maintains UI simplicity
- Opacity slider decoupling preserves Cristian's existing watermark intensity via v2 migration
