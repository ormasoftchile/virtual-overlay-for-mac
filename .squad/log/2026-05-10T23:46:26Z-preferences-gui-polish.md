# Session Log: Preferences GUI Polish

**Session start:** 2026-05-10T23:46:26Z  
**Focus:** Don tasks 13–16 (opacity slider, font family, live preview, label updates)  

## Work Summary

Recorded four completed don tasks implementing Preferences UI refinements:
- Opacity slider decoupled from Color (v2 migration)
- Font family curated picker: SF Pro, SF Mono, New York, Helvetica Neue, Menlo (v3 migration)
- Live label binding to @State during slider drag
- Watermark position-reset fix (whole-draft live preview, hover-flee preservation)

All 33 tests passing; bundle.sh clean.

## Decisions Recorded

Added 6 new decisions to decisions.md (decisions 7–12):
- v2 & v3 preference schema migrations
- Live state ownership and full-snapshot preview rules
- Heuristic CGS re-bind retirement
- SwiftPM bundle script

Deduplicated 2 pre-existing decisions (Susan icon, Ken per-display CGS).

## Output Artifacts

- `.squad/orchestration-log/2026-05-10T23:46:26Z-don-preferences-gui.md` — detailed task manifest
- `.squad/decisions.md` — merged and deduplicated (updated size: ~25KB)
- `.squad/log/2026-05-10T23:46:26Z-preferences-gui-polish.md` — this log

## Next: Git Commits

Source code commit + Squad memory commit staged and ready.
