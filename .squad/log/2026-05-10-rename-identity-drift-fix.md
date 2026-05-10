# Session: 2026-05-10-rename-identity-drift-fix.md

**Date:** 2026-05-10T16:28:42.833-04:00  
**Trigger:** User report "renamed 2 to second, will always show third"  
**Requester:** ormasoftchile (Cristian)

## Fixes Applied

1. **Removed re-bind-on-launch heuristic** — Old entries without CGS ID no longer auto-attach to new session CGS IDs. They remain dormant until user explicitly renames under CGS-backed identity.

2. **Fresh identity at rename commit** — `OptionClickRenameController.submitRename()` now captures current Space identity at Enter time, not from cached/captured value at click-down. Uses `SpaceFingerprinter.currentIdentity()` direct path.

## Root Cause

- v1.2 re-bind logic on first launch matched heuristic fingerprints to new session CGS IDs, poisoning old names into wrong Spaces.
- Rename path captured identity at interaction start; this stale value was then persisted, locking in the wrong Space binding.

## Result

✓ 24 tests, 0 failures  
✓ Watermark names now stable across Space visits  
✓ UNNAMED fallback preserved for true ambiguity
