# Squad Decisions

## Active Decisions

### 1. Project Shape & Module Boundaries
**Proposed by:** Edsger  
**Date:** 2026-05-10  
**Status:** Proposed  
**Full proposal:** `.squad/agents/edsger/proposals/2026-05-10-architecture-v1.md`

**Decision:**
1. **Project shape:** SwiftPM packages (`Packages/`) for all domain modules, with a thin Xcode `.xcodeproj` app target (`VirtualOverlay/`).
2. **Four modules + app shell:**
   - `OverlayRenderer` — transparent NSWindow + SwiftUI watermark
   - `SpaceDetection` — pluggable strategies, emits SpaceID
   - `Persistence` — SpaceID → name mapping, local JSON
   - `Interaction` — Option-click, hotkeys, menu; coordinates the other three
   - `VirtualOverlay` (app target) — wiring only, no domain logic
3. **Dependency graph (acyclic):** App → Interaction → {OverlayRenderer, SpaceDetection, Persistence → SpaceDetection}
4. **No sandbox at v1.** Revisit at v2 if public APIs prove sufficient.
5. **macOS 13+ minimum deployment target.**

---

### 2. v1 Distribution Architecture (Public APIs Only)
**From:** Alan (Researcher)  
**Date:** 2026-05-10  
**Status:** SUPERSEDED by Decision 3 (v1.2 lifts public-API constraint for Space identity)

**Recommendation (archived):** Commit to public APIs for v1.
- ✅ Notarization passes clean
- ✅ App Store eligible
- ✅ Zero permission prompts needed
- ✅ Low maintenance (public APIs stable)
- ✅ Proven model (Übersicht, Rectangle, AltTab)

**Implications (archived):** v1 direct distribution (GitHub) + notarization. No private CGS APIs in scope.

**Supersession note:** This decision was correct for general v1 distribution policy but did not account for the empirical impossibility of disambiguating sibling Spaces using only public APIs. Decision 3 (v1.2) lifts the constraint specifically for Space identity via `CGSGetActiveSpace`, while preserving the public-APIs-only policy for other modules.

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction

---

## Don Decision: JSON Space Name Store
**Date:** 2026-05-10T12:25:14.215-04:00  
**From:** Don  
**Status:** Proposed

Use a local Codable JSON file at `~/Library/Application Support/VirtualOverlay/spaces.json` for the v1 `SpaceIdentity → name` store.

**Reasoning:** JSON keeps the M1 persistence layer inspectable, testable under SwiftPM, and easy to migrate once Alan and Ken finalize stronger public-API Space identity heuristics. `UserDefaults` would hide schema shape and make orphaned Space mappings harder to review or clean up later.

---

## Alan → Don: Recommended v1 Space Identity (Persistence Module)
**Date:** 2026-05-10  
**From:** Alan (Researcher)  
**To:** Don (Persistence module lead)  
**Status:** Ready for review  
**Priority:** Blocking; needed before Persistence scaffold

**Summary:** Use Candidate B (Medium Identity) for v1 Persistence.

**Key recommendation:**
- Display UUID (hardware anchor via `CGDisplayCreateUUIDFromDisplayID`)
- Window signature (fuzzy match on ≥70% Jaccard overlap)
- Estimated ordinal (secondary signal, tie-breaker)
- User-set label (mutable)

**Match algorithm:** On `NSWorkspaceActiveSpaceDidChangeNotification`:
1. Exact match: all three signals match → return stored Space
2. Fuzzy match: display matches + ≥70% window set overlap (Jaccard) → update and return
3. Fallback: no match → create new, label "Untitled Space"

**Ken's blocking probes (must validate before lock-in):**
1. Display UUID stable across reboots + unplugging/replugging?
2. Does `CGWindowListCopyWindowInfo([.optionOnScreenOnly], …)` return only active Space windows or all Spaces?
3. Can ordinal be reliably inferred, or too noisy?
4. Do minimized windows appear in window list?
5. Does `NSWorkspaceActiveSpaceDidChangeNotification` fire reliably on Sequoia?

**Full detail:** `.squad/agents/alan/research/05-space-identity-heuristics.md`

---

## Don Decision: Option Interacts With Watermark
**Date:** 2026-05-10T15:50:52.457-04:00  
**From:** Don  
**Status:** Accepted (implemented in Don-5)

Holding Option is an explicit interaction signal for the watermark, not the screen behind it.

**Implications:**
- Overlay windows may receive mouse events while Option is held.
- Hover-flee must be suspended while Option is held.
- Option-click rename must target the watermark at its current visible position, including any fled corner.

**Rationale:** Fixes collision between hover-flee and Option-click rename. When user holds Option to click watermark, the watermark must remain visible and clickable even if it would normally flee. Rename hit-test respects the watermark's current position, accounting for any flee-driven corner relocation.

---

## Don Decision: Drop Space-Change Debounce (SUPERSEDES 250ms debounce approach)
**Date:** 2026-05-10T15:58:36.087-04:00  
**From:** Don  
**Status:** Accepted (implemented in Don-6)

**Supersedes:** Earlier M2 decision to debounce `NSWorkspaceSpaceDetector` notifications at 250ms before fingerprint collection.

New decision: emit Space-change events immediately on the main actor. Fingerprinting plus store lookup is cheap enough, and duplicate notification bursts are handled by idempotent output: `OverlayController.updateText(_:)` no-ops when the resolved name is already displayed.

**Implications:**
- Space switches should update the watermark with no perceptible debounce gap.
- Watermark text changes snap.
- Position changes, including hover-flee, remain animated.

**Implementation detail:** Replaced 250ms debounce with output-side dedup—if resolved name == currently displayed, no-op. Watermark text changes now snap; only position changes (hover-flee) animate.

**Test Result:** 15 tests, 0 failures

---

## Don Decision: Space Identity v1.1 (SUPERSEDED by Decision 3: v1.2)
**Date:** 2026-05-10T16:06:03.295-04:00  
**From:** Don  
**Status:** SUPERSEDED — Provided incremental improvement but did not resolve root collision class

**Decision (archived):** Space identity v1.1 adds discriminating public-API signals to the fingerprint.

**What was added:**
- `displayUUID`
- `windowSignature`
- `frontmostAppBundleID` ← NEW: discriminates sibling Spaces with similar window sets
- `windowCount` ← NEW: secondary cardinality signal
- `windowGeometrySignature` ← NEW: hash of window bounds
- `ordinal`
- `firstSeen`

**Why it failed:** When two Spaces have the same foreground app (or no foreground app), all discriminators remain identical. Alan's research confirmed that `CGWindowListCopyWindowInfo` returns the same window set for sibling Desktop Spaces, violating the core assumption. Matcher correctly returned nil (ambiguous), but user cannot disambiguate if every visit to either Space produces the same "UNNAMED" watermark.

**Supersession note:** Decision 3 (v1.2) adds session-scoped `cgsSpaceID` from `CGSGetActiveSpace`, which provides a numeric ID that trivially disambiguates sibling Spaces. The v1.1 enriched fingerprint signals are retained as fallback heuristics. The root collision problem is now solved; v1.1 was a necessary but insufficient partial fix.

**Migration:** All v1.1 JSON entries remain valid; v1.2 adds the CGS ID field (optional, nullable) and adds CGS exact-match to the highest-priority match tier.

---

## 3. Decision: Space Identity v1.2 — Lift Public-API-Only Constraint
**Author:** Edsger (Lead / Xcode & Architecture)  
**Date:** 2026-05-10  
**Status:** Decided  
**Supersedes:**
- Edsger's v1 public-API-only ratification (Decision 2)
- Don's Space Identity v1.1 decision

### The decision

**Path A — Lift the public-API-only constraint for v1.2.** Introduce a `CGSPrivateSpaceDetector` strategy that calls `CGSGetActiveSpace` (via `CGSMainConnectionID`) to obtain the session-scoped numeric Space ID from Core Graphics Services. This strategy slots behind the existing `SpaceDetectionStrategy` protocol with zero changes to the protocol surface. The public-API `NSWorkspaceSpaceDetector` is retained as the automatic fallback if the private call fails or returns 0.

**Rationale:** Public macOS APIs cannot reliably distinguish two Desktop-style Spaces on the same display when they have similar or no foreground apps — Cristian has hit this collision class twice, and Don's v1.1 enrichment of the fingerprint did not resolve it because `CGWindowListCopyWindowInfo([.optionOnScreenOnly])` does not actually scope to the active Space. `CGSGetActiveSpace` returns a per-session unique numeric ID that trivially disambiguates sibling Spaces; the `SpaceDetectionStrategy` protocol was designed for exactly this extension point, and our v1 distribution posture (direct distribution, no App Store, no sandbox) already absorbs the notarization and breakage risks.

### What failed

1. **v1 public-API-only identity:** Display UUID + window-set Jaccard + ordinal. Failed because `CGWindowListCopyWindowInfo` returns the same window set for sibling Desktop Spaces.

2. **v1.1 enriched fingerprint:** Added `frontmostAppBundleID`, `windowCount`, `windowGeometrySignature`. Failed for the same root cause — when two Spaces have the same foreground app (or no foreground app), the fingerprint is identical.

3. **The fundamental limit:** No combination of public signals can distinguish two Spaces that look the same to the windowing server's public interface. Cristian's experience is the empirical answer: **the worst case is real and common.**

### Why Path A, not B or C

- **Path B (UX-only fix):** When every Space produces the same fingerprint, the user cannot disambiguate. Path B is necessary but not sufficient.

- **Path C (session-local visit-order tracking):** Fragile — returning to Space 2 after visiting Space 3 produces the same fingerprint as the first visit to Space 2.

- **Path A (private API):** `CGSGetActiveSpace` returns a unique integer per Space per session. It solves the disambiguation problem completely within a session. Combined with the existing `firstSeen` timestamp and user rename, it provides a solid identity anchor.

### Implementation directive for Don

**Goal:** Wire `CGSGetActiveSpace` into the identity pipeline. No changes to `SpaceDetectionStrategy`, `OverlayRenderer`, or `Interaction`.

#### Step 1 — Add CGS declarations (new file)

Create `Sources/SpaceDetection/CGSPrivate.swift` with runtime-resolved private CGS symbols via `dlsym`. If the symbols are unavailable (future macOS), all lookups return nil.

#### Step 2 — Add `cgsSpaceID` to `SpaceIdentity`

Add `public let cgsSpaceID: UInt64?` to `SpaceIdentity`. Default it to `nil` in the `init(from decoder:)` path so existing JSON entries decode without migration.

#### Step 3 — Populate CGS ID in `SpaceFingerprinter`

In `SpaceFingerprinter.currentSnapshots()`, after building the fingerprint, attempt to resolve the CGS ID and pass it into the `SpaceIdentity` initializer.

#### Step 4 — Update match priority in `JSONFileSpaceNameStore`

In `match(currentFingerprint:)`, before the existing exact-signal match, add CGS exact-match as highest priority:
- If `currentCGS` and stored `cgsSpaceID` are both non-nil and match, return the stored entry.

#### Step 5 — Invalidate stale CGS IDs on launch

In `JSONFileSpaceNameStore.init`, after loading from disk, nil out all `cgsSpaceID` values (they don't survive across sessions).

#### Step 6 — Confidence upgrade

When `cgsSpaceID` is non-nil and matched, set `SpaceDetectionConfidence` to `.high`.

#### Step 7 — Tests

- Add a test that two `SpaceIdentity` values with different `cgsSpaceID` but identical public signals match to different stored names.
- Add a test that when `cgsSpaceID` is nil on the current fingerprint, fallback to existing signal/fuzzy matching works unchanged.
- Add a test that stale CGS IDs (loaded from disk) don't prevent matching when a fresh CGS ID is available.

#### What NOT to change

- `SpaceDetectionStrategy` protocol — no changes needed.
- `OverlayRenderer` — no changes.
- `Interaction` — no changes.
- The UNNAMED fallback — keep it.

### Reversal acknowledgment

This decision explicitly reverses Edsger's own v1 public-API-only ratification. The ratification was correct given the information available at the time. What we underestimated was the **within-session disambiguation** value of `CGSGetActiveSpace`: it doesn't solve persistence, but it does solve identity, and identity was the actual blocker. The right call today is more important than consistency with yesterday's right call.

**Full specification:** `.squad/decisions/inbox/edsger-space-identity-v1.2.md`

---

## 4. Decision: Per-display CGS Space Contract (Ken Correction to v1.2)
**Author:** Ken  
**Date:** 2026-05-10T17:18:00.082-04:00  
**Status:** Supersedes Edsger v1.2's `CGSGetActiveSpace` implementation detail
**Supersedes:** Edsger/Don Space Identity v1.2 (implementation detail only)

### The correction

Don's v1.2 implementation used `CGSGetActiveSpace(connection)` as the private CGS identity source. This symbol is private and returns the globally active Space for the **currently focused display**, not the current Space for an arbitrary monitor.

For multi-display correctness, Space identity capture must call the private per-display symbol:

```c
CGSSpaceID CGSManagedDisplayGetCurrentSpace(CGSConnectionID cid, CFStringRef displayUUID);
```

The SkyLight/SLS-prefixed alias (`SLSManagedDisplayGetCurrentSpace`) is equivalent prior art.

### Contract

When creating a `SpaceIdentity` for an `NSScreen`:

1. Resolve that screen's `CGDirectDisplayID`
2. Convert to display UUID string via `CGDisplayCreateUUIDFromDisplayID()`
3. Call `CGSManagedDisplayGetCurrentSpace(connection, displayUUID)` per display
4. Store returned Space ID with corresponding `displayUUID`
5. Match CGS IDs only when both `cgsSpaceID` and `displayUUID` match

### Fallback chain

1. `CGSManagedDisplayGetCurrentSpace`/`SLSManagedDisplayGetCurrentSpace` per display
2. `CGSGetActiveSpace`/`SLSGetActiveSpace` global fallback (only when per-display unavailable)
3. Existing public-API heuristic fingerprint when private symbols unavailable

Each fallback level emits stderr diagnostics.

### Diagnosis & rationale

Cristian's multi-display setup exhibited cross-display Space name binding: every display resolved to the same focused display's Space ID, causing all overlays to show the same name. The hypothesis: `CGSGetActiveSpace` is global to the keyboard-focused display. **The fix:** Use the per-display symbol `CGSManagedDisplayGetCurrentSpace` to resolve each overlay's display independently. This maintains the v1.2 strategy (private CGS for session-scoped disambiguation) while correcting the multi-display bug.

**GOTCHA:** `CGSGetActiveSpace` is private and returns the active Space for the **currently focused display**, not per-display. In multi-display setups it silently cross-binds Space names between monitors. Never use it as a per-display identity source; use only as a global compatibility fallback.

### Implementation status

- ✅ Per-display CGS resolver implemented in `SpaceDetection/CGSPrivate.swift`
- ✅ Fallback chain tested and validated
- ✅ 27 integration tests pass, 0 failures
- ✅ Regression tests added with loud GOTCHA comment at call site

---

## 5. Decision: Programmatic Typographic App Icon
**Author:** Susan  
**Date:** 2026-05-10T17:26:50.686-04:00  
**Status:** Approved  

### The decision

The app icon is a restrained typographic marker: a centered SF Pro ultra-light `V` framed by geometric bracket rules on a near-black macOS squircle. The icon is generated programmatically in Swift using Core Graphics / AppKit, not from a design tool. This reflects the project's infrastructural ethos.

### Visual spec

- **Canvas:** 1024×1024, visible squircle inset to 824×824 with 184 px corner radius
- **Background:** `#111416` near-black (sRGB 17, 20, 22) with slight blue-green cast
- **Foreground:** `#F4F1EA` (sRGB 244, 241, 234) at 94% opacity
- **Type:** SF Pro Display, `.ultraLight` weight, 500 px size, centered
- **Frame:** Two 16 px bracket rules at x = 284 and x = 740, y = 304…720, with 44 px horizontal returns
- **Edge rule:** `#FFFFFF` at 7% opacity, subtle bevel
- **Shadow:** Black at 18% opacity, soft and minimal
- **No gradients, color accents, skeuomorphism, or metaphorical elements**

### Rationale

The product itself is a persistent text watermark for spatial orientation. A pure typographic `V` framed like architectural signage rhymes with that watermark's ambient, restrained aesthetic (Bloomberg terminal labels, NYC subway signage, architectural marking systems). At small sizes (16×16), the refined ultra-light type softens but the centered V plus bracket stems preserve the infrastructural signage read.

### Implementation

- **Generator:** Swift CLI at `Tools/IconGenerator/` using AppKit/Core Graphics to produce the 1024 source; `iconutil` generates all required PNG sizes and `.icns` output
- **Outputs:** Generated assets checked in at `Resources/AppIcon.iconset/` and `Resources/AppIcon.icns` so fresh clones do not need to run the generator
- **Bundle wiring:** `bundle.sh` copies `Resources/AppIcon.icns` to `dist/Virtual Overlay.app/Contents/Resources/AppIcon.icns` and sets `CFBundleIconFile = AppIcon` in `Info.plist`
- **Commit:** Susan shipped in commit 7622eed

### Why source-of-truth in code

The icon is generated by a small program, not committed as a binary blob. This aligns with the project's "designed in code" philosophy: the specification is the Swift generator, not a Figma mockup or static PNG. Future visual iteration has a clear foothold; the mark can evolve by changing type weight, frame geometry, or palette values in code.

---

## 6. Decision: Watermark Preferences v1
**Author:** Don  
**Date:** 2026-05-10T19:06:07.182-04:00  
**Status:** Approved  

### The decision

Watermark appearance preferences (color, font size, position) are persisted to a dedicated JSON file separate from the Space-identity store. Preferences are edited via a native macOS preferences window (Cmd-, shortcut in status-bar menu) with live preview—changes apply immediately to all overlays without an Apply button. Disk writes debounce at 500ms after the last UI change to keep slider interactions responsive.

### Preferences schema

```swift
struct WatermarkPreferences: Codable {
    var color: CodableColor
    var fontSize: CGFloat
    var position: WatermarkPosition
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}
```

Storage location: `~/Library/Application Support/VirtualOverlay/preferences.json`

Defaults preserve the pre-preferences hardcoding:
- **Color:** white sRGB RGBA `(1, 1, 1, 0.10)` — 10% white
- **Font size:** `240` points
- **Position:** `.lowerRight`

### Live preview implementation

1. **Shared `WatermarkAppearance` observable:** Single source of truth for all preference state.
2. **Preferences window writes:** Modifies `WatermarkAppearance` directly; changes publish to subscribers.
3. **OverlayController subscribes:** Re-renders watermark immediately on any preference change.
4. **No Apply button:** All changes apply live, mirroring native macOS preference UI patterns.
5. **Debounced disk writes:** 500ms debounce on disk I/O to avoid write thrash during slider drags; buffered writes flush on app termination.

### UI components (PreferencesView)

- **Color picker:** Native system color picker + 6 curated swatches matching Susan's design language (warm off-white / near-black palette)
- **Font size slider:** 80–400 points, with live preview across all overlays
- **Position picker:** 2×2 corner grid (upper-left, upper-right, lower-left, lower-right)

### Persistence layer (PreferencesStore protocol)

- **Protocol:** `PreferencesStore` defines load/save contract
- **Implementation:** `JSONFilePreferencesStore` handles disk I/O to `preferences.json`
- **Backward compatibility:** Intentionally independent from `spaces.json`; appearance schema migration and Space-name identity migration have different risks and timelines

### Implementation status

- ✅ Preferences window implemented (`PreferencesWindowController`)
- ✅ `WatermarkAppearance` observable shared between `PreferencesView` and `OverlayController`
- ✅ Color picker with 6 curated swatches
- ✅ Font size slider 80–400pt
- ✅ Position 2×2 corner picker
- ✅ 500ms debounced disk writes
- ✅ Status-bar menu gains "Preferences…" with Cmd-, shortcut
- ✅ 30 tests, 0 failures

### Design language integration

The 6 curated color swatches were chosen to match Susan's app icon design language: warm off-white (`#F4F1EA`) and near-black (`#111416`) primary palette, with complementary accents. This ensures preferences UI feels visually cohesive with the app's identity.

---

## 7. Decision: WatermarkPreferences v2 — Color and Opacity Split
**Author:** Don  
**Date:** 2026-05-10T19:18:41.680-04:00  
**Status:** Proposed  
**Supersedes:** WatermarkPreferences v1

### The decision

`WatermarkPreferences` v2 separates color and opacity:

```swift
struct WatermarkPreferences: Codable {
    var color: CodableColor
    var opacity: Double
    var fontSize: CGFloat
    var position: WatermarkPosition
}
```

The `color` field is now RGB only; alpha is normalized to `1.0` and ignored for rendering. `opacity` is the separate intensity control in `0.0...1.0`, exposed in Preferences UI as a 1%…100% slider.

### Migration rule

When loading v1 JSON with no `opacity` field, decode the stored `color.alpha` as the new `opacity` value, then normalize `color.alpha` to `1.0`. Saving after that writes the v2 schema, preserving Cristian's existing watermark intensity as a one-shot migration.

---

## 8. Decision: WatermarkPreferences v3 — Curated Font Family
**Author:** Don  
**Date:** 2026-05-10T19:32:38.748-04:00  
**Status:** Proposed  
**Supersedes:** WatermarkPreferences v2

### The decision

`WatermarkPreferences` v3 adds a curated font family selector:

```swift
struct WatermarkPreferences: Codable {
    var color: CodableColor
    var opacity: Double
    var fontSize: CGFloat
    var fontFamily: WatermarkFontFamily
    var position: WatermarkPosition
}

enum WatermarkFontFamily: String, Codable, CaseIterable {
    case sfPro
    case sfMono
    case newYork
    case helveticaNeue
    case menlo
}
```

### Font set rationale

The picker is intentionally bounded: SF Pro for system default, SF Mono for technical signage, New York for system serif, Helvetica Neue for classic macOS sans, and Menlo for developer fixed-width. No full system picker, user-installed fonts, or web fonts.

### Migration rule

When loading v1/v2 JSON with no `fontFamily` field, decode as `.sfPro`. Saving after that writes the v3 schema.

---

## 9. Decision: Live Preview Uses Complete Preference Snapshots
**Author:** Don  
**Date:** 2026-05-10T19:32:00.082-04:00  
**Status:** Proposed

### The decision

All Preferences live-preview controls must mutate a single local `WatermarkPreferences` draft and apply that whole snapshot to `WatermarkAppearance` / `OverlayController`. The 500ms debounce governs disk writes only; it must never be part of the overlay preview data path.

### Reasoning

Partial live updates can mix fresh slider values with stale position/color/font fields or trigger unwanted renderer-side state resets. Publishing and applying the full snapshot keeps all fields consistent for every preview frame.

### Follow-on rule

Renderer appearance changes should reset hover-flee home state **only** when `position` changes. Cosmetic changes (opacity, font size, color) must preserve the current visible watermark corner.

---

## 10. Decision: Live State Owns Slider Labels
**Author:** Don  
**Date:** 2026-05-10T19:25:28.374-04:00  
**Status:** Proposed

### The decision

SwiftUI slider rows that display their current numeric value should bind both the slider and the value label to the same live `@State` value. Persistence, save debouncing, and downstream observable objects may receive changes from that state but must not be the source of truth for the label during drag.

### Reasoning

A debounced or indirectly observed preference path can let the rendered overlay update while the label remains stale. Keeping the label on the slider's live state makes the UI truthful during continuous interaction and avoids jitter with `.monospacedDigit()`.

---

## 11. Decision: Retire Heuristic CGS Re-bind
**Author:** Don  
**Date:** 2026-05-10T16:28:42.833-04:00  
**Status:** Proposed  
**Supersedes:** Space Identity v1.2 re-bind-on-first-visit behavior

### The decision

Retire the automatic re-bind logic that matched heuristic-only stored entries (`cgsSpaceID = nil`) to a fresh session CGS Space ID on first visit.

On launch, stale CGS IDs are cleared in memory (they don't survive sessions). Any entry without a fresh CGS ID is dormant/orphaned data and must not be matched to or refreshed into a current CGS-backed identity.

### Rationale

The re-bind used the same heuristic matching that CGS identity was introduced to replace. In Cristian's failure case, an old entry named `third` could bind itself to the freshly detected CGS ID for Space 2, causing Space 2 to display `third` forever in that session.

Showing `UNNAMED` until the user renames each Space once under the CGS-backed identity is more honest than guessing.

### Rename invariant

Rename submit must capture the Space identity fresh at commit time, using the same `SpaceFingerprinter.currentIdentity()` path used by display refresh. The write must not use an identity cached by `WatermarkView`, `OverlayController`, or a closure captured at interaction time.

---

## 12. Decision: SwiftPM App Bundle Script
**Author:** Don  
**Date:** 2026-05-10T17:02:16.335-04:00  
**Status:** Implemented

### The decision

Keep the project SwiftPM-only and add a root `bundle.sh` script that wraps the release SwiftPM product into `dist/Virtual Overlay.app`.

### Specification

- **Bundle identifier:** `com.ormasoftchile.virtualoverlay`
- **Product source:** `swift build -c release --product VirtualOverlay`, copied from `.build/release/VirtualOverlay`
- **Bundle executable name:** `Virtual Overlay`, matching `CFBundleExecutable`
- **Version scheme:** script-local `CFBundleShortVersionString = 0.1.0` and `CFBundleVersion = 1` for v1
- **Minimum macOS:** `13.0`, matching `Package.swift`'s `.macOS(.v13)`
- **Launch Services:** `LSUIElement = true` in `Info.plist`; runtime uses accessory activation policy
- **Signing:** ad-hoc local signing only via `codesign --force --deep --sign -`; failures warn but do not fail the bundle build

### Non-goals

No Xcode project, notarization, DMG, Sparkle auto-update, or certificate setup in this step.

---

