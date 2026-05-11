# Don: Quarantine xattr is canonical ad-hoc install instruction

**Date:** 2026-05-10T20:10:01.513-04:00  
**From:** Don  
**Status:** Inbox decision note

For GitHub Release builds of Virtual Overlay, the canonical first-launch instruction is now:

```bash
xattr -dr com.apple.quarantine "/Applications/Virtual Overlay.app"
open "/Applications/Virtual Overlay.app"
```

Modern macOS no longer reliably allows right-click → Open for ad-hoc signed apps downloaded with quarantine attached. The `xattr -dr` step is the accurate documented escape hatch for this distribution tier.

If v2 distribution work is revisited, flag Alan's `distribution-research.md` for amendment: its older right-click → Open guidance missed the hardened Gatekeeper behavior now affecting Sequoia, Tahoe, and macOS 26.
