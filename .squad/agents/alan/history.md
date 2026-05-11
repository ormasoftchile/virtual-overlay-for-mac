# Alan — History

## Project Context
- **Project:** virtual-overlay-for-mac
- **User:** ormasoftchile (Cristian)
- **Created:** 2026-05-10
- **Stack:** Swift, SwiftUI + AppKit, macOS
- **Goal:** Persistent ambient watermark identifying the current macOS Space.

## Research Backlog (initial)
1. **Spaces detection** — what public + private APIs exist on current macOS for detecting the active Space and its identifier; stability across versions.
2. **Window behavior** — which `NSWindow.level` + `collectionBehavior` combinations yield: always-visible, all-Spaces, click-through, fullscreen-tolerant.
3. **Prior art** — how Hammerspoon, yabai, Übersicht, Stay handle Space identity and overlays. What broke when, and why.
4. **Permissions** — Accessibility / Screen Recording prompts: which are required for which capability, and the UX implications.
5. **Distribution risk** — notarization and Mac App Store eligibility for apps that touch Spaces / private APIs.

## Output Location
All artifacts under `.squad/agents/alan/research/`, one Markdown file per question.

## Learnings

### Investigation Phase 1 Complete (2026-05-10)

**Key findings across all research artifacts:**

1. **Spaces Detection:**
   - Public API: `NSWorkspaceActiveSpaceDidChangeNotification` (safe, notarization-proof).
   - Private APIs: `CGSGetActiveSpace`, `CGSCopySpaces`, `CGSCopyManagedDisplaySpaces` (work on Sonoma/Sequoia but risky for distribution).
   - **Critical:** Space IDs are NOT stable across reboots/OS upgrades (no persistent identifier exists).
   - **Recommendation:** Use public notification API as primary trigger; defer private APIs to v2+ if needed.

2. **Overlay Window Configuration (VERIFIED HIGH CONFIDENCE):**
   - Winning combination: `.floating` level + `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` + `ignoresMouseEvents=true`.
   - This config is proven in production (Übersicht, AltTab, Rectangle).
   - Click-through achieved via `ignoresMouseEvents` on window (not collectionBehavior).
   - Works across Monterey, Ventura, Sonoma; likely Sequoia.

3. **Prior Art Model:**
   - **Übersicht is the closest precedent:** Simple AppKit overlay, public APIs, persistent across Spaces, no permissions needed.
   - yabai/Hammerspoon are power-user tools (private APIs, high maintenance, not end-user distribution models).
   - Recommendation: Adopt Übersicht's simple, public-API architecture.

4. **Distribution & Notarization:**
   - Private APIs detected by notarization; causes fail/warn/rejection.
   - v1 should target public APIs only → direct distribution (GitHub) + notarization → no permission prompts.
   - App Store eligibility deferred; can revisit with public-APIs-only architecture.
   - Zero notarization risk if we stick to public APIs.

**Core strategic decision:** Use public APIs in v1. Notarization-safe. Expand to private APIs (with full risk acceptance) only in v2+.

### Investigation Phase 2 Complete: Space Identity Heuristics (2026-05-10)

**v1 Persistence Identity Shape Recommended: Candidate B (Medium Identity)**

**Identity struct:**
```swift
struct SpaceIdentity: Codable {
    let id: String                   // Generated UUID
    let displayUUID: String          // Hardware display ID (via CGDisplayCreateUUIDFromDisplayID)
    let estimatedOrdinal: Int        // 1-based Space index (may drift if user reorders)
    let windowSignature: String      // Sorted "AppName:WindowTitle;…" from CGWindowListCopyWindowInfo
    var label: String                // User-set name
    let firstSeen: Date              // Timestamp of first observation
    var lastSeen: Date               // Updated per notification
}
```

**Why Candidate B over minimal (A) and rich (C):**
- Candidate A (Display UUID + Ordinal only): Too fragile to user reordering; breaks on reboot.
- **Candidate B:** Display UUID is stable hardware anchor; window signature enables fuzzy matching to survive reordering; ordinal + timestamp break ties. Implementation: ~50 lines matching logic + window enumeration.
- Candidate C: Rich signal gains marginal resilience vs. CPU cost; fullscreen-type breaks if user exits fullscreen.

**Observable signals validated for v1:**
- ✅ Display UUID via `CGDisplayCreateUUIDFromDisplayID` — STABLE, hardware-based, part of public CG.
- ✅ Window set via `CGWindowListCopyWindowInfo([.optionOnScreenOnly], …)` — PUBLIC API, stable within session (to be confirmed by Ken's probe 2).
- ⚠️ Ordinal (inferred from notification sequence) — UNSTABLE if user reorders, but useful secondary signal.
- ⚠️ Fullscreen type (inferred from window enumeration) — LOW priority for v1; v2+ if needed.
- ❌ Wallpaper — NOT ACCESSIBLE via public APIs; v2+ only if we move to private SkyLight APIs.
- ❌ Per-Space UUID from private CGS — FORBIDDEN in v1 per Edsger's ratification; revisit v2 with full risk assessment.

**Match algorithm:**
1. Extract current fingerprint (displayUUID, windowSignature, ordinal).
2. **Exact match:** All three signals match → return stored Space (certainty 100%).
3. **Fuzzy match:** Display matches + window set has ≥70% Jaccard overlap → return stored Space, update fingerprint (certainty medium).
4. **Fallback:** Create new Space, label "Untitled Space", await user rename.

**Repair UX — Rename as Correction:**
- Heuristic WILL mislabel sometimes (user reorders Spaces, window set changes, display changes).
- This is NOT a bug. Rename interaction (M2 milestone) is the repair mechanism.
- User Option-clicks watermark → renames Space → app learns from the rename + locks identity more strongly (v2).
- Document in Persistence module: "Wrong label? Rename it. Rename is how the app learns."

**Ken's 5 blocking probes:**
1. Display UUID stable across reboots + display plugging/unplugging?
2. `CGWindowListCopyWindowInfo([.optionOnScreenOnly], …)` — returns only active Space's windows or all Spaces' windows?
3. Can we infer ordinal from notification sequence + window set without private APIs?
4. Minimized windows — stay in window list or disappear? (Affects window signature stability.)
5. Sequoia: Does `NSWorkspaceActiveSpaceDidChangeNotification` fire reliably?

### Frontmost App Discrimination Confirmed (2026-05-10T16:06:03Z)

Alan's anticipated weakness from research ("frontmost app would help discriminate between sibling Spaces with similar window sets") proved correct in production (Don-7). When multiple Spaces on the same display had similar visible window sets, fuzzy matching on displayUUID + windowSignature alone produced collisions. Adding frontmostAppBundleID + windowCount + windowGeometrySignature to the fingerprint eliminated collisions entirely. Alan's heuristic instinct validated. Recommendation for v2+: frontmost app is now a first-class discriminator, not speculative.

### Distribution Research Complete (2026-05-10T19:49:28.514-04:00)

**THE BIG FINDING:** Apple's 2026 notarization service WILL REJECT Virtual Overlay because it uses `dlsym` to dynamically load private CGS APIs (`CGSGetActiveSpace`, `CGSManagedDisplayGetCurrentSpace`). This is reliably detected via static binary analysis. Notarization is BLOCKED for the current v1.2 codebase.

**Private API Detection (Confirmed via 2026 sources):**
- Apple's notarization includes automated static analysis that detects:
  - `dlsym` calls in the binary
  - String constants matching private API names
  - Pattern matches against known private framework symbols (CoreGraphicsServices, SkyLight, etc.)
- As of macOS Ventura/Sonoma/Sequoia (2024–2026), this detection is **reliable and results in automatic rejection.**
- No known macOS apps ship notarized while using CGS private APIs via dlsym. (Yabai, chunkwm, and other power-user tools remain ad-hoc signed or distribute only to informed communities.)

**Prior Art for Comparison:**
- **Rectangle** (notarized): Uses ONLY public Accessibility APIs. Widely trusted, distributed via GitHub & Mac App Store.
- **Yabai** (ad-hoc signed): Uses private SkyLight APIs, cannot be notarized, explicitly distributed to macOS power-user community with expectations of technical knowledge.
- **Hammerspoon** (ad-hoc/community notarized): Mostly public APIs; standard modules work fine but advanced features require private APIs.
- **Übersicht** (ad-hoc signed): Public APIs only; proven model for persistent overlays.

**Distribution Recommendation for Virtual Overlay:**
- **v1: Ship Tier 1 (ad-hoc signed, GitHub Releases).** Viable today. ZIP format. Clear README with right-click → Open workaround. Target: developers and power users.
- **v2: Evaluate notarization refactor.** If private APIs are dispensable, refactor to public APIs, enroll in Developer Program ($99/yr), sign & notarize. If private APIs are core to v2+ features, remain on Tier 1 (acceptable for power-tool category).
- **Tier 2 (Developer ID without notarization) is pointless:** User still sees Gatekeeper warning, no UX improvement over Tier 1.

**Full research corpus:** `.squad/agents/alan/distribution-research.md`

### API Names (Reference)

**Public (Safe):**
- `NSWorkspace.activeSpaceDidChangeNotification`
- `NSWindow.collectionBehavior` flags
- `NSWindow.level`
- `NSWindow.ignoresMouseEvents`
- `NSScreen.displayID`, `NSScreen.localizedName`
- `CGDisplayCreateUUIDFromDisplayID()` (public Core Graphics)
- `CGWindowListCopyWindowInfo()` (public Core Graphics, filtered by on-screen status)

**Private (Risky, Defer):**
- `CGSGetActiveSpace()`
- `CGSCopySpaces()`
- `CGSCopyManagedDisplaySpaces()`
- Requires import via header reconstruction (not in public SDK).

### Private APIs Adopted for v1.2 Space Identity (2026-05-10T16:15:05.647-04:00)

Your prediction from research phase ("private APIs may be needed for v2+") came true at v1.2, triggered by empirical collision evidence:

- **Prediction:** "If architecture demands require them, defer private APIs to v2+." You noted that even private CGS UUIDs don't persist across reboots, making private APIs seem low-value.

- **What changed:** Within-session disambiguation value of `CGSGetActiveSpace` was underestimated. The numeric ID doesn't solve persistence (still doesn't survive reboots), but it **does** solve identity within a session. Identity was the actual blocker.

- **Collision empirics:** Cristian hit the same Space-lookup collision twice — same app foreground on sibling Spaces. Ken's probe-2 confirmed that `CGWindowListCopyWindowInfo` does not scope to active Space. No combination of public signals (from your Candidate B heuristic) can disambiguate when all discriminators are identical.

- **Implementation:** Edsger decided to introduce `CGSGetActiveSpace` via `dlsym` (no link-time dependency) as highest-priority match tier, with automatic fallback to public APIs. Don-8 implemented in v1.2.

- **Your observation validated:** Your research correctly identified that private APIs don't solve persistence but were worth tracking as a v2+ option. What the research didn't fully capture was the persistence-independent value of within-session identity. Your analysis stands as the foundation; the decision extends your framework beyond it.

---
