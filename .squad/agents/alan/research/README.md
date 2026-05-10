# Research Corpus Index

**Last updated:** 2026-05-10  
**Status:** Phase 2 research complete (5 artifacts); awaiting Ken's probes before v1 lock-in.

---

## What's Here

This directory contains the investigation corpus for the virtual-overlay-for-mac project. Each artifact answers a specific architectural question with findings, confidence levels, and actionable recommendations.

### Artifacts

1. **`01-spaces-detection-apis.md`**  
   Surveys public NSWorkspace and private CGS APIs for detecting the active Space. Covers `CGSGetActiveSpace`, `CGSCopySpaces`, `CGSCopyManagedDisplaySpaces`. Clarifies that Space identifiers are **not stable across reboots**; recommends using `NSWorkspaceActiveSpaceDidChangeNotification` as primary trigger (public, notarization-safe).

2. **`02-overlay-window-behavior.md`**  
   Documents NSWindow configuration for persistent overlays. Covers `.level` (floating), `.collectionBehavior` flags (`.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`, `.ignoresCycle`), and click-through mechanics. Provides recommended starting configuration for Ken to prototype.

3. **`03-prior-art.md`**  
   Surveys how Hammerspoon, yabai, Übersicht, AltTab, Rectangle, and Stay handle Spaces and overlays. **Key finding:** Übersicht is the closest precedent for our use case (public APIs, persistent overlay, all-Spaces visibility). Recommends adopting their architectural model (simple, notarization-safe, proven).

4. **`04-permissions-and-distribution-risk.md`**  
   Risk assessment of permissions (Accessibility, Screen Recording, Input Monitoring) and distribution paths (direct notarization vs. Mac App Store). **Key finding:** v1 should use public APIs only (no permission prompts, notarization-proof, App Store eligible long-term). Private APIs deferred to v2+ if needed.

5. **`05-space-identity-heuristics.md`** ⭐ **NEW**  
   Deep dive on persistent Space identity without stable UIDs. Surveys observable signals (Display UUID via `CGDisplayCreateUUIDFromDisplayID`, window signature via `CGWindowListCopyWindowInfo`, ordinal index, fullscreen type). Recommends Candidate B identity (Display UUID + Window Signature + Ordinal + Timestamp) for v1. Includes exact/fuzzy match algorithm, repair UX (rename as correction), and 5 Ken probes to validate assumptions.

---

## Quick Reference: Recommendations

| Question | Recommendation | Confidence |
|----------|-----------------|-----------|
| Which Space detection API to use? | `NSWorkspaceActiveSpaceDidChangeNotification` (public) as primary; defer CGS to v2+ | HIGH |
| Which window configuration? | `.floating` level + `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` + `ignoresMouseEvents=true` | HIGH |
| Which prior art model? | Adopt Übersicht architecture: simple, public-API overlay, trigger-based content refresh | HIGH |
| What permissions needed for v1? | None. No permission prompts required. | HIGH |
| Distribution path for v1? | Direct distribution (GitHub) with notarization. Public APIs only. | HIGH |
| How to identify persistent Spaces? | **Display UUID (hardware) + Window Signature (fuzzy match) + Ordinal (inferred) + Timestamp.** Exact/fuzzy match algorithm in 05-space-identity-heuristics.md. | MEDIUM-HIGH |
| How to correct mislabeled Spaces? | User rename via watermark option-click (M2 milestone). Rename is the repair mechanism, not app auto-correction. | HIGH |

---

## Next Up: Research Backlog

### Immediate (before Don scaffolds Persistence module)
- [ ] **Ken's 5 probes (blocking):** Validate display UUID stability, window list scope, ordinal inference, minimized window handling, Sequoia notification reliability. See 05-space-identity-heuristics.md section "Open Questions for Ken."
- [ ] Edsger review 05-space-identity-heuristics.md; confirm Candidate B (Medium Identity) alignment with Persistence module scope.

### Short-term (v1 lock-in)
- [ ] Verify on Sequoia (if beta/release available) that public APIs still work.
- [ ] Document v1 release checklist (notarization pass, public APIs only, permission audit).

### Medium-term (v2 planning)
- [ ] If multi-display support becomes priority, probe NSScreen multi-display behavior.
- [ ] If "smart Space detection" becomes priority, revisit CGS APIs with full risk assessment.
- [ ] Monitor macOS releases for new public APIs relevant to Spaces.

### Long-term (expansion planning)
- [ ] If Mac App Store release becomes goal, lock in public-APIs-only architecture.
- [ ] If private API features desired, write detailed trade-off document for team consensus.

---

## How to Use This Corpus

1. **For Edsger (Architect):** Read `03-prior-art.md` (Übersicht model) + `04-permissions-and-distribution-risk.md` (v1 posture) + `05-space-identity-heuristics.md` (Persistence identity shape). Decision summary: **Use public APIs; adopt Übersicht pattern; confirm Candidate B identity for Persistence.**

2. **For Ken (Implementer):** Read `02-overlay-window-behavior.md` (recommended starting config) + probe section of `01-spaces-detection-apis.md` + Ken's 5 probes in `05-space-identity-heuristics.md`. Start prototyping with the recommended NSWindow config; execute probes before Persistence scaffold.

3. **For Don (Persistence module lead):** Read `05-space-identity-heuristics.md` sections 3–5 (recommended identity struct, match algorithm, repair UX). Start scaffolding Persistence with Candidate B shape; await Ken's probe results before finalizing matching logic.

4. **For Cristian (Product):** Read executive summary in `04-permissions-and-distribution-risk.md` (v1 release criteria) + "Repair UX" section in `05-space-identity-heuristics.md` (rename as correction mechanism). This defines M2 interaction spec.

---

## Sources Cited

- **Hammerspoon hs.spaces:** https://github.com/asmagill/hs._asm.undocumented.spaces
- **yabai (Spaces API):** https://github.com/koekeishiya/yabai/wiki/Spaces-API
- **Übersicht (widget engine):** https://github.com/felixhageloh/ubersicht
- **AltTab (window switcher):** https://github.com/lwouis/alt-tab-macos
- **Rectangle (window snapper):** https://github.com/rxhanson/Rectangle
- **Apple AppKit documentation:** https://developer.apple.com/documentation/appkit
- **Apple notarization:** https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **App Store Review Guidelines:** https://developer.apple.com/app-store/review/guidelines/

---

## Research Quality Notes

- **Findings marked HIGH confidence:** Verified against multiple production tools, Apple documentation, or both.
- **Findings marked MEDIUM confidence:** Cross-referenced but less corroboration; recommend probe before committing.
- **Findings marked LOW confidence:** Single source or theoretical; require experimentation.
- **All external links verified as of 2026-05-10.**

---

## Next Steps

1. **Edsger:** Review `03-prior-art.md` and `04-permissions-and-distribution-risk.md`; confirm v1 posture.
2. **Ken:** Review `02-overlay-window-behavior.md`; begin prototype.
3. **Alan (Researcher):** Stand by for probe results from Ken. Update corpus as needed when Sequoia releases.
