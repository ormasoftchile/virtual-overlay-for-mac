# Orchestration: Distribution Pipeline & Release Infrastructure
**Date:** 2026-05-10T20:01:07.560-04:00 UTC  
**Session ID:** scribe-distribution-pipeline

## Agents Involved

- **alan-2:** Distribution research corpus. Determined notarization is impossible for v1 (private SkyLight APIs via dlsym, confirmed Yabai precedent). Recommended Tier 1: ad-hoc signed, ZIP via GitHub Releases.
- **don-17:** Built ship.sh release pipeline (ditto ZIP, SHA-256, RELEASE_NOTES.md stub, prints `gh release create` command). Updated bundle.sh to accept version. Wrote README with install instructions including right-click→Open caveat. Verified with `./ship.sh 0.1.0-rc1 --allow-dirty`: 33 tests passing.

## Decisions Ratified

1. **Decision 12: Distribution Model — Tier 1 (ad-hoc signed, GitHub Releases)**  
   Distribute Virtual Overlay v1.0 via ad-hoc signed ditto ZIP on GitHub Releases. Notarization not viable due to private API usage. Tier 1 is proven for power-user tools (Yabai, Hammerspoon, Übersicht precedent). Users accept right-click → Open workaround.

2. **Decision 13: Release Pipeline — ship.sh is Canonical Local Path**  
   Local release builds via `./ship.sh VERSION`: runs tests, builds app, verifies ad-hoc signature, clears extended attributes, creates ditto ZIP with SHA-256 sidecar and RELEASE_NOTES.md stub. Prints `gh release create` command for manual publish; no CI signing for v1.

## Artifacts Produced

- `ship.sh` — Release orchestration script (tests → build → sign verify → ditto ZIP → SHA-256 → RELEASE_NOTES stub)
- `bundle.sh` — Updated to accept VERSION argument
- `README.md` — Installation instructions with right-click→Open caveat and notarization limitation explanation
- `.gitignore` — Updated to exclude dist/ build artifacts

## Test Status

- `./ship.sh 0.1.0-rc1 --allow-dirty`: **33 tests passing, 0 failures**

## Next Steps

1. Cristian ratifies Decisions 12 & 13.
2. Create first GitHub Release (tag v1.0.0, attach ZIP + SHA-256).
3. Announce to audience; monitor user feedback on right-click→Open friction.
4. Track Tier 3 (notarization) feasibility for v2 based on user demand.

