# Research: Permissions & Distribution Risk Assessment

**Date:** 2026-05-10  
**Researcher:** Alan  
**Status:** Initial

---

## Question

What permissions (Accessibility, Screen Recording, Input Monitoring) are required for which capabilities? What are the UX implications of permission prompts? What notarization and Mac App Store eligibility constraints apply to private API usage? What should our v1 distribution posture be?

---

## Findings

### Permission Requirements Matrix

| Capability | Public API / Requirement | Permission Needed | UX Implication | Notarization Risk | App Store Eligible |
|------------|--------------------------|-------------------|----------------|-------------------|-------------------|
| **Detect active Space (public)** | `NSWorkspaceActiveSpaceDidChangeNotification` | None | No prompt | None | ✅ Yes |
| **Detect active Space (private)** | `CGSGetActiveSpace` (private API) | None (but SIP may apply) | No prompt | ⚠️ High (private API detected) | ❌ No |
| **Query all Spaces (private)** | `CGSCopySpaces` (private API) | None | No prompt | ⚠️ High | ❌ No |
| **Move windows between Spaces** | Not publicly available | Accessibility (via SIP/entitlements) | Accessibility prompt | ⚠️ High (entitlements + private APIs) | ❌ No |
| **Overlay window (basic)** | `NSWindow`, `collectionBehavior` | None | No prompt | None | ✅ Yes |
| **Detect fullscreen app** | `NSWorkspaceDidActivateApplicationNotification` + public APIs | None | No prompt | None | ✅ Yes |
| **Screen Recording (capture screenshot)** | `CGWindowListCreateImage`, `CGDisplayCreateImage` | Screen Recording (macOS 10.15+) | System prompt | ⚠️ Medium (permission check) | ✅ Yes (if requested) |
| **Input Monitoring (keyboard/mouse)** | `NSEvent` event tap (`CGEventTapCreate`) | Input Monitoring | System prompt | ⚠️ Medium (permission check) | ✅ Yes (if requested) |

---

### Detailed Permission Analysis

#### 1. Accessibility Permission

**When needed:** Apps that programmatically control windows (move, resize, focus) or inject events.

**macOS mechanism:**
- **System Preferences > Security & Privacy > Privacy > Accessibility** (pre-Ventura).
- **System Settings > Privacy & Security > Accessibility** (Ventura+).
- User must manually enable; no API to programmatically grant (security restriction).

**UX flow:**
1. App attempts operation requiring accessibility.
2. System shows native prompt (cannot be customized).
3. User must navigate to System Settings and enable manually.
4. App must be restarted or user must close and reopen app.

**For our watermark:**
- **Not needed** if we only detect Space changes and render overlay (no window manipulation).
- **Would be needed** if v2 requires moving windows or injecting shortcuts.

**Risk for notarization:** None if just checking permission. High if attempting to bypass or automate the prompt.

**Reference:** https://developer.apple.com/documentation/appkit/nsapplication/requestuser(authentication:)

---

#### 2. Screen Recording Permission

**When needed:** Apps that capture screen pixels (screenshots, recording, screen analysis).

**macOS mechanism (10.15+):**
- **System Preferences > Security & Privacy > Privacy > Screen Recording** (pre-Ventura).
- **System Settings > Privacy & Security > Screen Recording** (Ventura+).
- APIs to check and request:
  ```swift
  let hasPermission = CGPreflightScreenCaptureAccess() // Returns true/false, no prompt
  CGRequestScreenCaptureAccess() // Shows prompt
  ```

**UX flow:**
1. App calls `CGRequestScreenCaptureAccess()`.
2. System shows native prompt (cannot be customized).
3. User approves or denies.
4. Permission persists across app restarts (until user revokes).

**For our watermark:**
- **Not needed** for displaying overlay (we're rendering within our own window, not capturing screen).
- **Would be needed** if v2 requires analyzing what's on screen (e.g., to adapt watermark to app content).

**Notarization impact:** None. Screen Recording permission is officially supported for notarized apps.

**App Store impact:** ✅ Allowed if permission is clearly disclosed in App Description.

**Reference:** https://developer.apple.com/documentation/coregraphics/1454426-cgrequestscreencaptureaccess

---

#### 3. Input Monitoring Permission

**When needed:** Apps that monitor or intercept keyboard/mouse events globally (not just within the app's window).

**macOS mechanism:**
- **System Settings > Privacy & Security > Input Monitoring** (Ventura+).
- **No public API** to request or check this permission programmatically; users must enable manually.

**UX flow:**
1. App uses `CGEventTapCreate()` or similar to monitor global events.
2. System shows prompt (once, at first usage or installation).
3. User navigates to Settings to enable.
4. No built-in "redirect to Settings" link; user must know to go there.

**For our watermark:**
- **Not needed** for basic overlay and Space detection.
- **Would be needed** if we require global keyboard shortcuts (e.g., Cmd+Ctrl+1 to switch Spaces).

**UX problem:** Input Monitoring prompt is less discoverable than Accessibility; users often miss it.

**Notarization impact:** None if permission is properly declared.

**App Store impact:** ✅ Allowed if disclosed; some apps have been approved.

**Reference:** https://developer.apple.com/forums/thread/123542

---

### Private API & Notarization

#### What Happens During Notarization

1. **Apple receives binary.**
2. **Static analysis:** Notarization service scans for:
   - Private/undocumented symbols (e.g., `CGSGetActiveSpace`, `_SomethingPrivate`).
   - Suspicious patterns (e.g., runtime code injection, entitlement abuse).
   - Notarized malware signatures.
3. **Result:** Notarization passes or fails with detailed log.

#### Private Symbols Detected by Notarization

Example symbols that trigger rejection:

- `_CGSGetActiveSpace` — detected (rejected if symbols not stripped).
- `_CGSCopySpaces` — detected (rejected).
- `_CGSCopyManagedDisplaySpaces` — detected (rejected).
- `_SkyLight` (Spaces internals) — detected (rejected).

**What "detected" means:** Notarization log includes warning; notarization may **fail** or **pass with warning** depending on severity and whether you're distributing outside the App Store.

#### Notarization Policy

| Scenario | Private API Used? | Direct Distribution | Mac App Store |
|----------|-------------------|-------------------|------------------|
| Public APIs only | No | ✅ Notarization passes | ✅ App Store approves |
| Private CGS APIs | Yes | ⚠️ Notarization may fail or pass with warning | ❌ App Store rejects (policy 2.5.1) |
| Private APIs + obfuscation | Yes | ⚠️ May trigger security flags | ❌ Rejected |

**Source:** Apple App Store Review Guidelines 2.5.1: "Apps must use APIs and frameworks for their intended purposes and indicate that integration in their app's metadata when required. Apps that use non-public APIs will be rejected."

---

### Mac App Store Eligibility

#### Current Policy

- **Public APIs only:** ✅ Eligible.
- **Private APIs:** ❌ **Automatic rejection** during review. No exceptions.
- **Entitlements (SIP-bypass, input monitoring, etc.):** ⚠️ Require justification; usually rejected unless app is first-party or has special approval.

#### Examples of Rejected macOS Apps

- yabai (window manager) — uses private CGS APIs + requires SIP disable. **Not on App Store.**
- Hammerspoon hs.spaces — uses private APIs. **Not on App Store; distributed directly.**
- Rectangle — uses *only* public APIs. ✅ **On Mac App Store since v0.1.**

---

### Distribution Paths & Their Trade-offs

#### Path 1: Direct Distribution (Notarized, Public APIs Only)

**Description:** Build and sign binary; request notarization; distribute via GitHub, website, or installer.

**Requirements:**
- Valid Apple Developer ID ($$$ yearly).
- Code signing certificate.
- Notarization process (takes 5–30 min typically).

**Pros:**
- No App Store review process (faster releases).
- Can use some private APIs without automatic rejection (notarization may warn or fail).
- Can set own auto-update frequency and content.

**Cons:**
- No visibility in Mac App Store (less discoverability).
- User must manually download and install (trust barrier higher).
- User experience for updates is manual (unless you implement Sparkle or similar).

**For our watermark:** Recommended if using public APIs only. Safe, fast path to market.

---

#### Path 2: Mac App Store

**Description:** Submit app to Mac App Store; Apple reviews and distributes.

**Requirements:**
- Same Apple Developer ID.
- Xcode validation (automatic checks).
- App Store Connect (submission interface).
- Compliance with 1000+ review guidelines.

**Pros:**
- Automatic notarization (no separate step).
- Distribution via trusted App Store (high discoverability, built-in updates).
- User confidence ("App Store is safer").

**Cons:**
- App Store review can take 24–72 hours or longer.
- No private APIs allowed (automatic rejection).
- Apple takes 30% commission (free apps unaffected; paid/in-app purchases charged).
- Stricter sandbox restrictions.

**For our watermark:** Only viable if using public APIs exclusively. Good for long-term, but slower iteration.

---

#### Path 3: Enterprise / Direct + Private APIs (High Risk)

**Description:** Use private APIs, distribute directly, attempt notarization (may fail or warn).

**Requirements:**
- Accept notarization failure risk.
- Implement fallbacks if APIs break on OS updates.
- Plan for frequent maintenance with each macOS version.

**Pros:**
- Access to more detailed Space information (CGS APIs).
- Can build more advanced features (window manipulation, etc.).

**Cons:**
- **Notarization will likely fail or warn** (private API detected).
- **Must sign and distribute without notarization** (Gatekeeper prompt on first run: "This app is from an unknown developer").
- **Break risk on OS updates:** Every macOS update may break the app.
- **Maintenance burden:** High. Continuous compatibility work.
- **App Store impossible.**
- **User trust degraded** (unknown developer prompt is scary).

**Examples:** yabai, Amethyst (power-user tools accept this trade-off).

**For our watermark:** Not recommended for v1. Accept for power-user v2+ if needed.

---

### Recommended v1 Distribution Posture

| Decision | Rationale |
|----------|-----------|
| **Use public APIs only** | Notarization-safe; future-proof; App Store eligible long-term. |
| **Direct distribution (GitHub releases)** | Faster iteration than App Store; simpler than App Store review. |
| **Sign + notarize** | Professional, trusted distribution (higher user confidence). |
| **No permission prompts needed** | Space detection via `NSWorkspaceActiveSpaceDidChangeNotification`; overlay via AppKit (no permissions). |
| **Auto-update via Sparkle (optional v1+)** | Adds polish; defer to v2 if necessary. |
| **Defer private APIs to v2+** | If architecture demands more detail, revisit then with full risk assessment. |

---

## Risk Registers

### Notarization Risks

| Risk | Probability | Impact | Mitigation |
|------|-----------|--------|-----------|
| Private APIs detected; notarization fails | HIGH (if CGS used) | **CRITICAL** — Can't distribute | Don't use private APIs in v1. |
| Compiler strips symbols; false pass | LOW | Minor — App breaks on run | Test binary on clean machine post-notarization. |
| Apple changes notarization policy | LOW | **CRITICAL** — App becomes untrusted | Monitor Apple's developer forums; prepare migration. |

### App Store Risks

| Risk | Probability | Impact | Mitigation |
|------|-----------|--------|-----------|
| Review rejection (private API) | HIGH (if CGS used) | **CRITICAL** — Can't ship on App Store | Commit to public APIs in v1. |
| Sandbox restrictions break features | MEDIUM | High — May require entitlements | Test sandbox mode during dev. |
| Review rejection (permission justification) | LOW (if public APIs) | Medium — Retry with better explanation | Clearly document why permission needed. |

### Maintenance Risks

| Risk | Probability | Impact | Mitigation |
|------|-----------|--------|-----------|
| macOS update breaks private APIs | VERY HIGH (if used) | **CRITICAL** — App breaks | Continuous monitoring; requires v2 update immediately. |
| Public API deprecated | VERY LOW | Medium — Refactor code | Public APIs are stable; Apple maintains backward compatibility. |

---

## Recommendation for v1 Release Criteria

**Go/No-Go Checklist:**

- [ ] **No private APIs used** — `grep` binary for `_CG`, `_SkyLight`, other private symbols.
- [ ] **Notarization passes clean** — No warnings about private APIs.
- [ ] **Sign + distribute** — GitHub releases with signed + notarized .dmg.
- [ ] **Permission prompts minimal** — Ideally zero; if needed, test UX with beta users.
- [ ] **Test on Sonoma + Sequoia (if beta available)** — Ensure public APIs work as expected.
- [ ] **Document v2 path** — If we want more features requiring permissions/private APIs, document trade-offs.

---

## Open Questions

1. **Can we use `NSWorkspaceActiveSpaceDidChangeNotification` without any permissions?**
   - **Answer:** Yes (based on documentation and prior art).
   - **Probe:** Ken should test minimal app that registers for notification; verify no prompt appears.

2. **Does Screen Recording permission affect notarization for a "check permission" call?**
   - **Answer:** No. Checking permission status is safe; requesting permission is safe. Notarization doesn't care.
   - **Source:** Apple notarization documentation.

3. **If we need multi-display support, do we need additional permissions?**
   - **Answer:** No. NSScreen is public API.
   - **Probe:** Multi-display testing deferred to v2.

---

## References

- **Apple App Store Review Guidelines:** https://developer.apple.com/app-store/review/guidelines/
- **Code Signing & Notarization:** https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **Accessibility (NSAccessibility):** https://developer.apple.com/documentation/appkit/nsapplication/requestuser(authentication:)
- **Screen Recording (CGRequestScreenCaptureAccess):** https://developer.apple.com/documentation/coregraphics/1454426-cgrequestscreencaptureaccess
- **Input Monitoring Forums:** https://developer.apple.com/forums/thread/123542
- **yabai on App Store eligibility:** https://github.com/koekeishiya/yabai/issues (search "App Store")

---

## Summary for Cristian (Product)

**For v1, target direct distribution with notarization, using public APIs only.** This keeps the product shipping fast, notarization-safe, and future-proof. No permission prompts needed. If future versions need more advanced features (specific Space targeting, window control), we can revisit private APIs at that point with full stakeholder buy-in on the trade-offs (maintenance burden, distribution restrictions, notarization risk).
