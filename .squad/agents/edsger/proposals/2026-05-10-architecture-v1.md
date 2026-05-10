# Architecture Proposal: Virtual Overlay for Mac — v1

**Author:** Edsger (Lead / Xcode & Architecture)  
**Date:** 2026-05-10  
**Status:** Ratified (Revision 3)  

---

## Revision 3 — 2026-05-10 — Space Identity Reckoning

### What Changed

I am reversing the public-API-only constraint for Space identity detection. The v1.2 identity pipeline will use `CGSGetActiveSpace` (resolved at runtime via `dlsym`, no link-time dependency) to obtain the session-scoped numeric Space ID from Core Graphics Services. This slots into the existing `SpaceFingerprinter` with no changes to the `SpaceDetectionStrategy` protocol.

### Why — the empirical failure chain

1. **First collision report (Cristian):** "I renamed the second Space to 'second'. For second and third I see the same name." Root cause: the public-API fingerprint (display UUID + window signature + ordinal) was identical for two Desktop-style Spaces with the same foreground app.

2. **Don's v1.1 enrichment:** Added `frontmostAppBundleID`, `windowCount`, `windowGeometrySignature`, tightened the fuzzy matcher (Jaccard ≥ 0.8, winner margin ≥ 0.15). The matcher now correctly returns nil on ambiguity, showing "UNNAMED."

3. **Second collision report (Cristian, post-v1.1):** "I named the third one. Now 2 and 3 appear the same." Same collision class with the richer fingerprint. The enrichment didn't fix it because `CGWindowListCopyWindowInfo([.optionOnScreenOnly])` returns the same window set for sibling Spaces — it does not scope to the active Space. Ken's probe-2 flagged this as needing manual validation; Cristian's experience is the empirical answer.

4. **Alan's research (01-spaces-detection-apis §Private CGS APIs, 05-space-identity-heuristics §6 question 2):** Explicitly anticipated that window-list scope might not distinguish sibling Spaces and flagged private APIs as the v2 escape hatch.

### The fundamental limit

No combination of public signals — display UUID, window set, frontmost app, window count, geometry hash, ordinal — can distinguish two Desktop-style Spaces on the same display when both have similar or identical visible state. This is not a "slightly tighter heuristic" problem. The public window-list API does not scope to the active Space. The information the fingerprinter needs does not exist in the public API surface.

### What Revision 3 changes in the architecture

| Section | Change |
|---------|--------|
| SpaceDetection (§2.2) | `SpaceFingerprinter` now attempts `CGSGetActiveSpace` via runtime `dlsym`. Returns session-scoped `UInt64` Space ID. Falls back to public signals if unavailable. |
| SpaceIdentity struct | Gains `cgsSpaceID: UInt64?`. Nil when private API unavailable or across session boundaries. |
| Persistence match priority | CGS exact match (highest) → signal exact match → fuzzy match → UNNAMED. |
| Entitlements (§4) | No change. We already skip sandbox. Private API usage is compatible with hardened runtime + direct distribution. |
| Distribution (§5) | No change for v1 (direct distribution). App Store eligibility is explicitly deferred. Notarization should be tested with a CGS-calling binary before release. |

### What does NOT change

- `SpaceDetectionStrategy` protocol — untouched. The CGS call lives inside the fingerprinter, not as a separate strategy. The protocol remains the v2 extension point for a full CGS strategy that enumerates all Spaces.
- `OverlayRenderer` — no changes.
- `Interaction` — no changes.
- The UNNAMED fallback — stays. If CGS is unavailable AND public signals are ambiguous, UNNAMED is correct.
- Module dependency graph — unchanged: `App → Interaction → {OverlayRenderer, SpaceDetection, Persistence → SpaceDetection}`.

### Risk mitigation

Private API code is isolated to one file (`CGSPrivate.swift`), resolved at runtime via `dlsym` (no link-time symbol dependency), and gated by nil-checks. If `CGSGetActiveSpace` vanishes on a future macOS, the optional is nil and the public-API fingerprint path activates automatically. The existing UNNAMED-on-ambiguity behavior remains the safety net.

### Reversal acknowledgment

This reverses my own Revision 2 ratification. That decision was correct given available information: Alan's research showed CGS UUIDs don't persist across reboots, making private APIs seem low-value for *persistence*. What we underestimated was the *within-session disambiguation* value of `CGSGetActiveSpace`. It doesn't solve persistence (nothing does), but it solves identity — and identity was the actual user-facing blocker.

**Full decision details:** `.squad/decisions/inbox/edsger-space-identity-v1.2.md`

---

## Revision 2 — 2026-05-10 — Public-API-Only v1

### What Changed

After reviewing Alan's four research artifacts, I am ratifying the **public-API-only** posture for v1. This revision updates the proposal to reflect that decision and its downstream effects.

**Key findings from Alan's research that drove this revision:**

1. **`01-spaces-detection-apis.md`:** No stable, persistent Space identifier exists — not even via private APIs. CGS UUIDs change across reboots and Mission Control modifications. This means private APIs don't actually solve the persistence problem we assumed they would. The public `NSWorkspace.activeSpaceDidChangeNotification` is the only high-confidence detection signal.

2. **`02-overlay-window-behavior.md`:** The full overlay window configuration (`.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`, `.ignoresCycle`, `ignoresMouseEvents`, `.floating` level) uses exclusively public AppKit APIs. No private API is needed for the renderer.

3. **`03-prior-art.md`:** Übersicht is the closest precedent — a production overlay engine using only public APIs, stable for years. Rectangle and AltTab further confirm that `.canJoinAllSpaces` overlays work reliably with public APIs alone.

4. **`04-permissions-and-distribution-risk.md`:** Private CGS symbols are detected by Apple's notarization service and trigger rejection. Public-API-only apps pass notarization clean, require zero permission prompts, and preserve App Store eligibility.

**What this changes in the proposal:**

| Section | Change |
|---------|--------|
| SpaceDetection (§2.2) | Only public-API strategy ships in v1. Protocol stays for v2 extensibility. |
| Persistence (§2.3) | Schema explicitly documents heuristic/ordinal Space identity and its limits. |
| Entitlements (§4) | Sandbox rationale updated — we skip sandbox for simplicity, not for private API access. Hardened runtime is now compatible. |
| Build & Signing (§5) | Hardened runtime can be enabled. Notarization is achievable whenever we want it. |
| Open Questions (§7) | All four questions answered by Alan's research. Marked resolved. |
| M1 (§8) | Multi-monitor kept (public API is sufficient). Added note that detection stub need not simulate private APIs. |

---

## 1. Project Shape Decision

**Choice: SwiftPM-based with a thin Xcode app shell.**

The app target lives in an `.xcodeproj` (required for Info.plist, entitlements, code signing, LSUIElement, and the bundle structure macOS needs for a menu-bar agent app). All domain logic lives in SwiftPM packages that the app target depends on. This gives us: (a) clean module boundaries enforced by the compiler — you literally cannot import what you haven't declared as a dependency, (b) each package is independently testable with `swift test`, no Xcode scheme gymnastics, and (c) local iteration stays fast because SwiftPM resolution is near-instant for local packages.

A pure `.xcodeproj` with group-based "modules" provides no real boundary enforcement. A pure SwiftPM executable can't carry a bundle, entitlements, or LSUIElement. The hybrid is the only option that satisfies all three constraints.

---

## 2. Module Breakdown

### 2.1 OverlayRenderer

| Attribute | Value |
|---|---|
| **Swift target name** | `OverlayRenderer` |
| **Responsibility** | Owns the transparent, click-through NSWindow and the SwiftUI view hierarchy that draws the watermark on each display. |
| **Does NOT** | Decide *what text* to show (receives it). Does not detect Spaces. Does not persist anything. Does not handle user input beyond forwarding Option-click to the interaction layer. |

```swift
// OverlayRenderer/Sources/OverlayRendererProtocol.swift

import AppKit

public struct OverlayContent: Sendable {
    public let text: String
    public let opacity: CGFloat          // 0.05 – 0.12 range
    public let screenID: CGDirectDisplayID
}

public protocol OverlayRendering: AnyObject, Sendable {
    /// Show or update overlays on all specified screens.
    func update(content: [OverlayContent])

    /// Tear down all overlay windows.
    func hide()

    /// Publisher/callback for user interaction events on the overlay.
    var onInteraction: (@Sendable (OverlayInteractionEvent) -> Void)? { get set }
}

public enum OverlayInteractionEvent: Sendable {
    case optionClick(screenID: CGDirectDisplayID)
}
```

### 2.2 SpaceDetection

| Attribute | Value |
|---|---|
| **Swift target name** | `SpaceDetection` |
| **Responsibility** | Determines the current macOS Space identifier using one or more pluggable strategies, and emits change notifications. |
| **Does NOT** | Render anything. Persist names. Know what a "name" is — it deals in opaque Space identifiers. |

**v1 constraint (Revision 2):** Only the **public-API strategy** ships in v1. This strategy uses `NSWorkspace.activeSpaceDidChangeNotification` as its sole signal and produces a heuristic/ordinal `SpaceID` (e.g., an incrementing session-scoped counter). The `SpaceDetectionStrategy` protocol remains as the v2 extension point — a `PrivateCGSStrategy` could be plugged in later without touching other modules.

**Space identity model (Revision 2):** Per Alan's findings (`01-spaces-detection-apis.md`), no stable, persistent Space identifier exists on macOS — not even via private CGS APIs. UUIDs from `CGSCopyManagedDisplaySpaces` do not survive reboots or Mission Control modifications. The `SpaceID` type is therefore an **opaque, session-scoped heuristic** in v1. All downstream consumers (persistence, interaction) must treat it as potentially unstable.

```swift
// SpaceDetection/Sources/SpaceDetectionProtocol.swift

import Foundation

/// Opaque identifier for a macOS Space.
///
/// ⚠️ v1 LIMITATION: This ID is a session-scoped heuristic produced by the
/// public-API detection strategy. It is NOT a system-provided UUID. It may
/// not survive app restarts, reboots, or Mission Control Space reordering.
/// Consumers (especially persistence) must document and handle this.
public struct SpaceID: Hashable, Codable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String)
}

public struct SpaceSnapshot: Sendable {
    public let currentSpaceID: SpaceID
    public let displayID: CGDirectDisplayID
    public let confidence: SpaceDetectionConfidence
    public let timestamp: Date
}

public enum SpaceDetectionConfidence: Sendable, Comparable {
    case low, medium, high
}

public protocol SpaceDetecting: AnyObject, Sendable {
    /// One-shot: what Space is active right now?
    func currentSpace() async throws -> [SpaceSnapshot]

    /// Continuous observation. Calls back on every detected change.
    func startObserving(onChange: @escaping @Sendable ([SpaceSnapshot]) -> Void)
    func stopObserving()
}

/// Individual detection strategies conform to this.
/// v1 ships only PublicAPISpaceDetectionStrategy.
/// v2 may add PrivateCGSStrategy behind this same protocol.
public protocol SpaceDetectionStrategy: Sendable {
    var name: String { get }
    func detect() async throws -> [SpaceSnapshot]
}
```

### 2.3 Persistence

| Attribute | Value |
|---|---|
| **Swift target name** | `Persistence` |
| **Responsibility** | Stores and retrieves `SpaceID → user-chosen name` mappings. Local-only, single JSON file in Application Support. |
| **Does NOT** | Know about displays or overlays. Does not sync, does not migrate across machines, does not validate names. |

**v1 Space-identity model (Revision 2):** The persistence layer stores names keyed by `SpaceID`, but must treat those IDs as **heuristic and potentially unstable**. Per Alan's research (`01-spaces-detection-apis.md`), no macOS API — public or private — provides a Space identifier that reliably persists across reboots, OS upgrades, or Mission Control modifications. The v1 persistence schema therefore:

- Stores `SpaceID → name` mappings as best-effort.
- **Documents in code** that mappings may become orphaned when the underlying Space ID changes (reboot, Space reorder, etc.).
- Provides `allNames()` so the UI can show orphaned mappings for user cleanup.
- Does NOT attempt cross-session Space identity correlation or migration logic.
- Keeps the schema simple enough that v2 can swap in a more stable ID source without schema migration.

```swift
// Persistence/Sources/PersistenceProtocol.swift

import Foundation

/// A user-assigned name for a detected Space.
///
/// ⚠️ v1 LIMITATION: The spaceID is a session-scoped heuristic. Stored
/// mappings may become orphaned after app restart, reboot, or Mission
/// Control Space reordering. This is a known limitation of the public-API
/// detection strategy. The UI should handle orphaned entries gracefully
/// (e.g., allow re-assignment or cleanup).
public struct SpaceName: Codable, Sendable {
    public let spaceID: SpaceID
    public let name: String
    public let updatedAt: Date
}

public protocol SpaceNameStore: Sendable {
    func name(for spaceID: SpaceID) -> String?
    func setName(_ name: String, for spaceID: SpaceID) throws
    func allNames() -> [SpaceName]
    func removeName(for spaceID: SpaceID) throws
}
```

Note: `SpaceID` is defined in `SpaceDetection`. `Persistence` imports `SpaceDetection` — this is the **only** cross-module import in the domain layer, and it's for a single value type.

### 2.4 Interaction

| Attribute | Value |
|---|---|
| **Swift target name** | `Interaction` |
| **Responsibility** | Handles user-initiated actions: Option-click rename flow, global hotkeys, and the status-bar menu. Coordinates between renderer, detection, and persistence. |
| **Does NOT** | Draw overlays (delegates to OverlayRenderer). Detect Spaces (reads from SpaceDetection). Persist directly (calls Persistence). |

```swift
// Interaction/Sources/InteractionProtocol.swift

import Foundation

public protocol InteractionCoordinating: AnyObject, Sendable {
    /// Wire up interaction handling. Called once at app launch.
    func start()

    /// Trigger the inline rename flow for the current Space.
    func beginRename()

    /// Stop handling interactions (cleanup).
    func stop()
}
```

### 2.5 App (thin shell)

The `VirtualOverlay` app target contains:
- `AppDelegate` — creates concrete instances of all four protocols, wires dependencies, calls `start()`.
- No domain logic. If you're writing an `if` statement in the app target, you're in the wrong module.

---

## 3. Folder Layout

```
virtual-overlay-for-mac/
├── VirtualOverlay/                     # Xcode app target
│   ├── VirtualOverlay.xcodeproj/
│   ├── Sources/
│   │   ├── AppDelegate.swift           # Wiring only
│   │   └── main.swift                  # (or @main, whichever)
│   ├── Resources/
│   │   └── Assets.xcassets/
│   ├── Info.plist
│   └── VirtualOverlay.entitlements
│
├── Packages/                           # All SwiftPM modules
│   ├── OverlayRenderer/
│   │   ├── Package.swift
│   │   ├── Sources/
│   │   │   ├── OverlayRendererProtocol.swift
│   │   │   └── ...                     # Implementation (Don + Ken)
│   │   └── Tests/
│   │       └── OverlayRendererTests/
│   │
│   ├── SpaceDetection/
│   │   ├── Package.swift
│   │   ├── Sources/
│   │   │   ├── SpaceDetectionProtocol.swift
│   │   │   ├── SpaceID.swift
│   │   │   └── ...                     # Strategies (Ken + Alan)
│   │   └── Tests/
│   │       └── SpaceDetectionTests/
│   │
│   ├── Persistence/
│   │   ├── Package.swift
│   │   ├── Sources/
│   │   │   ├── PersistenceProtocol.swift
│   │   │   └── ...                     # JSON file store (Don)
│   │   └── Tests/
│   │       └── PersistenceTests/
│   │
│   └── Interaction/
│       ├── Package.swift
│       ├── Sources/
│       │   ├── InteractionProtocol.swift
│       │   └── ...                     # Rename flow, hotkeys, menu (Don)
│       └── Tests/
│           └── InteractionTests/
│
├── .squad/                             # Team state (existing)
├── .github/
├── README.md
└── .gitignore
```

### Dependency graph (acyclic, enforced by SwiftPM):
```
App → Interaction → OverlayRenderer
                  → SpaceDetection
                  → Persistence → SpaceDetection (SpaceID type only)
```

No cycles. `OverlayRenderer` and `SpaceDetection` depend on nothing in our graph. `Persistence` has a single, narrow import for the `SpaceID` value type. `Interaction` is the coordinator that ties the other three together. The `App` target imports only `Interaction` (and transitively the others for concrete type instantiation).

---

## 4. Entitlements & Info.plist Essentials

### Info.plist

| Key | Value | Why |
|---|---|---|
| `LSUIElement` | `true` | Agent app — no Dock icon, no main menu bar. Lives in the status bar. |
| `NSHumanReadableCopyright` | `© 2026 ormasoftchile` | Standard. |
| `CFBundleIdentifier` | `com.ormasoftchile.VirtualOverlay` | Unique ID. |
| `LSMinimumSystemVersion` | `13.0` | macOS Ventura — balances modern SwiftUI features with broad compatibility. (Revision 2: original rationale cited `CGSCopyManagedDisplaySpaces` availability, but since we no longer use private CGS APIs, the rationale is purely SwiftUI feature availability.) |

### Entitlements

| Key | Value | Why |
|---|---|---|
| `com.apple.security.app-sandbox` | **`false`** (not present) | v1 ships without sandbox for simplicity. Unlike the original proposal, this is **not** to enable private API usage (we no longer use any). It's because sandboxing adds complexity (file access restrictions, entitlement management) with no user-facing benefit for a local-only watermark app. Revisit at v2 if targeting Mac App Store. |
| `com.apple.security.automation.apple-events` | Not needed at v1 | We are not scripting other apps. |

### What we do NOT add yet
- Accessibility entitlements — not needed; public-API detection requires no Accessibility permission (`04-permissions-and-distribution-risk.md`).
- Network entitlements — no network calls in v1.
- Camera/microphone — obviously not.

---

## 5. Build & Signing Posture (v1)

| Aspect | v1 Posture |
|---|---|
| **Code signing** | Ad-hoc (`-`). Sign locally with `codesign --sign -`. No Apple Developer certificate required. |
| **Team ID** | None. |
| **Provisioning** | None. Not required for ad-hoc outside sandbox. |
| **Notarization** | Not performed at M1. However, public-API-only posture means notarization is achievable whenever we choose to add it — no private symbols to flag. |
| **Hardened Runtime** | Compatible with v1 (Revision 2). Since we use no private frameworks, hardened runtime can be enabled without exceptions. Defer enabling to when we set up notarization. |
| **Distribution** | Git clone + Xcode build. No DMG, no Homebrew cask. |

**When this must change:** Before any distribution to other users (even beta testers), we need:
1. An Apple Developer ID certificate for signing.
2. Hardened Runtime enabled (no exceptions needed — public APIs only).
3. Notarization via `xcrun notarytool`.
4. A DMG or zip for distribution.

This is explicitly out of scope for v1 M1 but is **unblocked** by the public-API-only decision.

---

## 6. Out of Scope (v1) — Reaffirmed

The following are **OUT** for v1. I will reject PRs that introduce them:

- ❌ Moving windows between Spaces
- ❌ Remembering/restoring window layouts per Space
- ❌ Mission Control automation or scripting
- ❌ Window tiling or arrangement
- ❌ Multi-user sync or cloud persistence
- ❌ Mac App Store distribution or sandboxing
- ❌ Notarization or distribution packaging
- ❌ System Preferences / Settings pane integration
- ❌ Accessibility-driven Space detection (RESOLVED: not needed; public `NSWorkspace` notification is sufficient per `01-spaces-detection-apis.md`)
- ❌ Menu bar icon customization beyond a basic SF Symbol
- ❌ Localization (English only for v1)

---

## 7. Open Questions for Alan — Status After Research

These were research questions whose answers would materially change the architecture. Alan's four research artifacts have answered all of them.

### RESOLVED: Q1 — Stable Space identifier on macOS 13+?
**Answer (`01-spaces-detection-apis.md`):** No stable, persistent Space identifier exists. Not even private CGS UUIDs survive reboots or Mission Control modifications. Space identity is inherently session-scoped.
**Impact:** `SpaceID` is a session-scoped heuristic. Persistence schema documents this honestly. No composite hashing strategy needed — the problem isn't solvable at the API level.

### RESOLVED: Q2 — How to detect Space changes in real time?
**Answer (`01-spaces-detection-apis.md`):** `NSWorkspace.activeSpaceDidChangeNotification` — public, stable since macOS 10.7, HIGH confidence. Private alternatives (`CGSRegisterNotifyProc`) offer no meaningful advantage for our use case.
**Impact:** `SpaceDetecting.startObserving()` is notification-driven, not poll-driven. Simplifies implementation significantly.

### RESOLVED: Q3 — Does NSWindow with canJoinAllSpaces work across Space transitions?
**Answer (`02-overlay-window-behavior.md`, `03-prior-art.md`):** Yes. `.canJoinAllSpaces` + `.fullScreenAuxiliary` + `.stationary` + `.ignoresCycle` + `.floating` level + `ignoresMouseEvents = true` is a proven configuration used by Übersicht, AltTab, and Rectangle. Works in fullscreen Spaces. Does NOT work during Mission Control animation (system-reserved; accepted limitation).
**Impact:** No architectural changes needed. The overlay approach is validated by production prior art.

### RESOLVED: Q4 — Private frameworks needed? SIP/entitlement implications?
**Answer (`01-spaces-detection-apis.md`, `04-permissions-and-distribution-risk.md`):** Private CGS APIs exist and work on current macOS, but they break notarization, are App Store ineligible, and provide no persistence benefit (UUIDs are unstable anyway). Public APIs are sufficient for v1.
**Impact:** Entire private-API concern is deferred to v2. No SIP workarounds, no `dlopen`, no hardened-runtime exceptions needed. Build/signing posture dramatically simplified.

### Remaining Open Questions

None blocking M1. The following are non-blocking items to validate during implementation:

- **Fullscreen edge cases:** Does `.fullScreenAuxiliary` work with all fullscreen modes (Safari, games, third-party apps)? Ken should test during M1 prototype.
- **Multi-monitor ordering:** When creating one overlay per `NSScreen`, is `NSScreen.screens` ordering stable enough to use as a display index? Ken should verify.

---

## 8. First Milestone: M1 — "It Draws a Watermark on Screen"

### M1 Includes

1. **Xcode project created** with the folder layout from §3.
2. **OverlayRenderer** implemented: a transparent, click-through `NSWindow` with `canJoinAllSpaces` behavior, hosting a SwiftUI view that displays a hardcoded string (e.g., "SPACE 1") at ~8% opacity, large centered text, on the primary display.
3. **App target** launches as an LSUIElement agent app. No Dock icon. Basic status-bar icon (SF Symbol `rectangle.stack`) with a Quit menu item.
4. **SpaceDetection** stubbed: returns a hardcoded `SpaceID("stub-1")`. The stub implements `SpaceDetectionStrategy` so the protocol is exercised. Real public-API detection (using `NSWorkspace.activeSpaceDidChangeNotification`) is M2. No private CGS APIs — not in the stub, not anywhere.
5. **Persistence** stubbed: in-memory dictionary. Real file persistence is M2.
6. **Interaction** stubbed: no Option-click, no hotkeys. Just the wiring that connects stub detection → stub persistence → renderer.
7. **Multi-monitor:** overlay appears on all connected displays (one window per `NSScreen`).
8. **All four SwiftPM packages compile** with `swift build`. Tests exist (can be minimal/placeholder) and pass with `swift test`.

### M1 Explicitly Excludes

- Real Space detection (hardcoded stub is fine)
- File-based persistence (in-memory is fine)
- Option-click rename
- Hotkeys
- Any Space-change observation
- Any typography tuning beyond "it's big and faded"
- Multi-Space awareness (one hardcoded label on all screens)

### M1 Definition of Done

> The app launches, shows no Dock icon, places a faded watermark reading "SPACE 1" on every connected display, and can be quit from the status-bar menu. Nothing else.

---

*End of proposal (Revision 2). Public-API-only v1 ratified. All open research questions resolved. Implementation may begin with M1.*
