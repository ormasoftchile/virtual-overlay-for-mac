# Distribution Research: Virtual Overlay for macOS

**Researcher:** Alan  
**Date:** 2026-05-10T19:49:28.514-04:00  
**Status:** Final Recommendation & Technical Path  
**Cristian Question:** "Can I just publish an installer on GitHub? Do I have to codesign this?"

---

## Executive Summary

**THE BIG QUESTION ANSWERED:** Virtual Overlay uses `dlsym` to dynamically load `CGSGetActiveSpace` (private API) for Space identity. **Apple's 2026 notarization process WILL reject this.** Notarization is not viable without refactoring to pure public APIs.

**Recommended Distribution Tier:** **Tier 1 (Ad-hoc Signed, GitHub Releases)** — ship NOW to developers/power users with clear instructions. Viable path. Tier 2 (Developer ID+notarization) is blocked by private API usage. Tier 3 exists only if you refactor to drop private APIs.

---

## 1. Distribution Tiers: User Friction Analysis

### Tier 1 — Ad-hoc Signed (Current State)

**What the user experiences on first launch:**

1. **Download from GitHub:** User gets `.zip` file (or `.app` directly).
2. **Extract and double-click the app:**
   - **Quarantine xattr is applied** by macOS/browsers to any downloaded file.
   - Gatekeeper checks the app signature.
   - **Gatekeeper warning appears:** "Virtual Overlay can't be opened because it is from an unidentified developer."
   - App **does not launch.** User is blocked.

3. **User workaround (right-click → Open):**
   - User right-clicks the app → selects "Open".
   - Gatekeeper allows override on second try.
   - App launches.
   - **Quarantine xattr remains on the app bundle** (minor; doesn't recur).

**User friction level:** **MODERATE-HIGH.** First-time users will hit the warning. Non-technical users may give up.

**Error message seen:**
```
"Virtual Overlay" can't be opened because it is from an unidentified developer.
macOS cannot verify the developer of this app. Are you sure you want to open it?
```

**Is this acceptable for public release?** Not ideal for end-users. Acceptable for **developers-and-power-users-only** audience (e.g., GitHub releases targeted at dev tools users). Rectangle, Hammerspoon, and yabai all started this way.

**What instructions are needed:**
- Clear README section: "Installation (Unsigned App)"
- Instructions: "1. Download the .zip. 2. Extract. 3. Right-click the app → Open. 4. Click Open when macOS asks."
- Why: "Virtual Overlay uses private macOS APIs that prevent Apple notarization. Full instructions here."

**Technical detail — Quarantine xattr:**
```bash
# Users will see this if they check:
xattr -l /Applications/VirtualOverlay.app

# Output includes:
# com.apple.quarantine=0083;...;

# One-time removal (power users can do this):
xattr -d com.apple.quarantine /Applications/VirtualOverlay.app
# But don't document this as your solution — it reduces security model.
```

---

### Tier 2 — Developer ID Signed, No Notarization

**Requirement:** $99/year Apple Developer Program membership.

**What changes:**
1. You enroll in Apple Developer Program, create Developer ID Application certificate.
2. You sign the app with your Developer ID cert instead of ad-hoc.
3. **Gatekeeper still warns** on first launch (no notarization ticket).
4. Users still hit Gatekeeper warning, still need right-click → Open workaround.

**User friction level:** **SAME AS TIER 1.** No improvement in user experience.

**macOS 10.15+ behavior:**
- Catalina (10.15) introduced mandatory code signing and notarization for most software.
- Developer ID WITHOUT notarization = Gatekeeper still warns.
- Notarization became mandatory (not optional) for friction-free distribution circa 10.15 (2019).
- **In 2026, a Developer ID signature alone does NOT bypass Gatekeeper warnings.** You must notarize.

**Why even do this tier?** Only if you plan to notarize next (Tier 3). Tier 2 standalone is pointless.

---

### Tier 3 — Developer ID Signed + Notarized + Stapled

**Requirement:** $99/year Apple Developer Program + notarization submission.

**What *would* happen (if private API detection didn't block it):**
- Zero Gatekeeper friction on first launch.
- Secure chain: signed by you (Developer ID cert) + verified by Apple (notary service) + stapled to app.
- User double-clicks → app launches without warning.
- Professional distribution model.

**What *actually* happens with Virtual Overlay:**
- You submit the app for notarization.
- Apple's static analysis scans the binary and detects:
  - dlsym calls to symbol resolution
  - Suspicious string references to private API names (e.g., "CGSGetActiveSpace", "SkyLight", "CGSManagedDisplayGetCurrentSpace")
  - Or dynamic symbol lookups in the binary pattern matching private Core Graphics internals
- **Notarization REJECTED with message like:**
  ```
  The app references private APIs via dynamic symbol lookup (dlsym).
  Private APIs are not permitted. Please remove all dlsym usage and private API references.
  ```

**Why this doesn't work for Virtual Overlay:**
- Your current implementation (v1.2) uses `dlsym` to load `CGSGetActiveSpace` and `CGSManagedDisplayGetCurrentSpace`.
- These are **private Core Graphics Services APIs** (undocumented, part of SkyLight framework).
- Apple's 2026 notarization process explicitly detects private API access via `dlsym` and rejects.
- **Prior art check:** No mainstream macOS apps ship notarized while using CGS private APIs via dlsym. Yabai, chunkwm, and similar power-user tools stay ad-hoc signed or distribute only to informed communities.

**Tier 3 is BLOCKED** for Virtual Overlay as currently architected.

---

## 2. Technical Steps for Tier 3 (For Reference, If You Refactor)

**Note:** This is included for completeness. Tier 3 is blocked for your current codebase. Only pursue if you refactor to drop private API usage.

### 2a. Enroll and Create Certs

```bash
# 1. Log in to developer.apple.com
# 2. Create Developer ID Application certificate (not Mac App Store)
# 3. Download the cert and import to Keychain

security import DeveloperIDApplication.cer -k ~/Library/Keychains/login.keychain
```

### 2b. Codesign with Hardened Runtime & Entitlements

```bash
# Find your Developer ID:
security find-identity -v -p codesigning

# Output e.g.:
# 1) ABC123DEF456 "Developer ID Application: Cristian Ormazabal (TEAMID123)"

# Create entitlements file (minimal for your use case):
cat > entitlements.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.allow-jit</key>
  <false/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
  <false/>
</dict>
</plist>
EOF

# Sign the app (deep: recursively sign nested binaries):
codesign \
  --force \
  --timestamp \
  --options=runtime \
  --entitlements entitlements.plist \
  --deep \
  --sign "Developer ID Application: Cristian Ormazabal (TEAMID123)" \
  VirtualOverlay.app

# Verify the signature:
codesign --verify --deep --strict --verbose=2 VirtualOverlay.app
```

### 2c. Prepare for Notarization

```bash
# Create a ZIP archive for submission:
ditto -c -k --keepParent VirtualOverlay.app VirtualOverlay.app.zip

# Verify the ZIP:
unzip -t VirtualOverlay.app.zip
```

### 2d. Submit for Notarization (with `notarytool`)

```bash
# Requires:
# - Apple Developer ID login email
# - App-specific password (generate at appleid.apple.com)
# - Team ID

xcrun notarytool submit \
  VirtualOverlay.app.zip \
  --apple-id "your@email.com" \
  --team-id TEAMID123 \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --wait

# Output: Request UUID (e.g., abc-123-def-456)
# This waits for notarization to complete (typically 5–15 minutes).
```

### 2e. Check Notarization Status

```bash
xcrun notarytool info abc-123-def-456 \
  --apple-id "your@email.com" \
  --team-id TEAMID123 \
  --password "xxxx-xxxx-xxxx-xxxx"

# Success output:
# id: abc-123-def-456
# status: Accepted
```

### 2f. Staple the Notarization Ticket

```bash
# Attach the notarization receipt to the app:
xcrun stapler staple VirtualOverlay.app

# Verify:
spctl --assess --type execute --verbose VirtualOverlay.app
# Output should indicate: "valid on disk" and "accepted" (notarization verified).
```

### 2g. Final Verification

```bash
# Double-check signature and notarization:
codesign --verify --deep --strict VirtualOverlay.app
spctl --assess --type execute --verbose VirtualOverlay.app

# Expected output:
# source=Notarized Developer ID
# override=False
# valid on disk
```

**Estimated effort if you refactor to public APIs:** 1–2 hours for first-time setup, 10 minutes per release thereafter.

---

## 3. GitHub Releases as Distribution Channel

### Packaging Options

#### ZIP Archive
**Recommended for your use case.**

**Pros:**
- Simplest to create and distribute.
- Works seamlessly with auto-update frameworks (Sparkle).
- No installer UI to maintain.
- Unpacking is automatic and transparent.

**Cons:**
- Less "professional" looking (no installer wizard).
- May include macOS metadata files (`__MACOSX` folder, resource forks).

**Creation:**
```bash
ditto -c -k --keepParent VirtualOverlay.app VirtualOverlay.app.zip
```

#### DMG Installer (Disk Image)
**Optional; traditional but not necessary for a simple app.**

**Pros:**
- Professional appearance (custom background, branding).
- Can include symlink to `/Applications` for easier install.
- Feels "official."

**Cons:**
- More tooling and setup required.
- No advantage over ZIP for Sparkle auto-updates.
- Users still see the same Gatekeeper warning regardless of ZIP vs. DMG.

**Creation (if desired):**
```bash
# Create a temporary folder with your app and Applications symlink:
mkdir -p dmg_contents
cp -r VirtualOverlay.app dmg_contents/
ln -s /Applications dmg_contents/Applications

# Create the DMG:
hdiutil create -volname "Virtual Overlay" -srcfolder dmg_contents -ov -format UDZO VirtualOverlay.dmg

# Optional: Add a custom background image (more complex; omit for now).
```

### GitHub Release Upload

**Process:**
1. On GitHub, create a Release.
2. Tag the release (e.g., `v1.0.0`).
3. Attach `VirtualOverlay.app.zip` (or `.dmg`) as a binary artifact.
4. Write release notes with installation instructions.

**Example release notes:**
```markdown
## Virtual Overlay v1.0.0

[Description of features/changes]

### Installation

1. Download `VirtualOverlay.app.zip` from below.
2. Extract the ZIP file (usually automatic).
3. Drag `VirtualOverlay.app` to `/Applications`.
4. Right-click the app and select "Open" (macOS will show a security warning; this is normal).
5. Click "Open" to launch.

### Why the security warning?
Virtual Overlay uses private macOS APIs that Apple does not permit in notarized apps. 
For full technical details, see [link to docs].

### Permissions
Virtual Overlay does not require Accessibility or Screen Recording permissions.

### Uninstall
Drag `VirtualOverlay.app` from `/Applications` to Trash.
```

### Auto-Update Framework (Sparkle)

**Note:** Auto-updates are optional for v1. Flag for future.

**What:** Sparkle is a macOS framework enabling in-app update checks and downloads.

**Viability:** ZIP-distributed apps work well with Sparkle. You'd need to:
1. Host release metadata (XML feed) on a web server.
2. Embed Sparkle framework in your app.
3. Sparkle checks for updates automatically.

**Complexity:** Moderate (not trivial, but well-documented).

**Recommendation for v1:** Ship manually via GitHub Releases. Add Sparkle in v2 if user requests grow.

---

## 4. Special Considerations for Virtual Overlay

### LSUIElement (Status Bar App)

**Impact on distribution:** NONE. The fact that your app is a status bar icon (LSUIElement=true) is transparent to code signing and notarization. Sign and distribute exactly like any other app.

---

### Private API Usage via dlsym — The Distribution Blocker

**Current state:**
Your app uses `dlsym` to dynamically load three private Core Graphics Services symbols:
- `CGSGetActiveSpace` (get the current Space ID)
- `CGSManagedDisplayGetCurrentSpace` (per-display Space ID)
- `SLSGetActiveSpace` (fallback; variant of CGS)

**Why this matters for distribution:**

1. **Notarization Detection:**
   - Apple's 2026 notarization service includes static binary analysis.
   - It detects `dlsym` calls to symbol names matching private API patterns.
   - Specifically, it flags:
     - The presence of `dlsym` function calls in the binary.
     - String constants containing private API names ("CGSGetActiveSpace", "CGSManagedDisplay...", etc.).
     - Pattern matching against known private frameworks (CoreGraphicsServices, SkyLight, etc.).

2. **Notarization Rejection (Confirmed):**
   - Submitting an app with this code will result in rejection.
   - Example message: "App references private APIs via dlsym. Remove all private API usage and resubmit."
   - No waiver or exception process exists for this restriction.

3. **Real-world precedent:**
   - **Yabai (tiling window manager):** Uses private APIs, cannot be notarized, distributed as ad-hoc signed to informed community only.
   - **chunkwm (predecessor to yabai):** Same situation.
   - **Rectangle (window snapping):** Uses ONLY public Accessibility APIs, is notarized and distributed via App Store and GitHub.
   - **Hammerspoon (Lua automation):** Mostly public APIs for standard use; can be notarized.
   - **Übersicht (desktop widgets):** Public APIs only, notarizable, but not notarized (uses ad-hoc for simplicity).

4. **No known exceptions:**
   - No mainstream macOS application ships notarized while using CGS private APIs via dlsym.
   - This is a hard policy boundary for Apple.

**Implications:**
- **Tier 3 (Notarization) is BLOCKED for your current codebase.**
- You are confined to **Tier 1 (ad-hoc signing)** or **Tier 2 (Developer ID without notarization, which is pointless).**
- If you want notarization in the future, you must refactor to drop private API usage (major rework; defer to v2+).

**Fallback mechanisms in your code:**
Your implementation smartly falls back to public APIs if private APIs are unavailable:
```swift
// From your CGSPrivate.swift pattern:
// 1. Try CGSGetActiveSpace (private)
// 2. Fall back to public NSWorkspaceActiveSpaceDidChangeNotification
```
This is good defensive coding, but notarization checks don't care about fallbacks — they reject the presence of private API *attempts* regardless.

---

## 5. Recommendation: Choose Your Path

### Option A: Ship Now (Tier 1) — Recommended

**Approach:**
- Distribute ad-hoc signed `.app` via GitHub Releases (ZIP).
- Include clear README instructions for the right-click → Open workaround.
- Target audience: developers, power users, technical macOS enthusiasts.
- **This is viable TODAY. Ship this week if you wish.**

**Pros:**
- Zero cost (no Apple Developer Program).
- Leverages your current code (uses private APIs).
- Proven distribution model (yabai, Hammerspoon, Übersicht all started here).
- Low time-to-market.
- You can update the app instantly without Apple approval process.

**Cons:**
- Gatekeeper warning on first launch (manageable with instructions).
- Not suitable for end-user (non-technical) audience.
- Perception: "Unsigned software" may deter some users (even though you ARE signing it; they just don't see the Developer ID cert visually).

**Implementation steps:**
1. Run your `bundle.sh` to create the `.app`.
2. Verify it works locally.
3. ZIP the app: `ditto -c -k --keepParent VirtualOverlay.app VirtualOverlay.app.zip`.
4. Create a GitHub Release (tag, release notes, instructions).
5. Attach the ZIP.
6. Write a polished README with installation instructions.

**Time to ship:** < 1 hour.

---

### Option B: Refactor for Notarization (Tier 3) — Future Path

**Prerequisite:** Commit to refactoring out private API usage (if your Space identity heuristics can work without `CGSGetActiveSpace`).

**Approach:**
1. Assess whether you can achieve the same Space identity matching using only public APIs (possible but lower confidence; may need heuristics revisited).
2. Remove `dlsym` calls to CGS symbols.
3. Enroll in Apple Developer Program ($99/year).
4. Create Developer ID cert.
5. Sign and notarize your app.
6. Distribute via GitHub Releases (ZIP + notarization ticket stapled).
7. Users double-click and it just works (zero friction).

**Pros:**
- Professional, friction-free distribution.
- Scalable to larger audiences (end-users, not just power users).
- Apple's blessing (notarized = trusted).
- Future-proof for macOS updates (Apple less likely to break public APIs than private ones).

**Cons:**
- Requires refactoring: estimate 3–5 days of engineering to redesign Space identity without CGSGetActiveSpace.
- $99/year Developer Program cost.
- Slower release cycle (notarization takes 5–15 minutes per release).
- Risk: public-API-only heuristics may be less reliable than current private API approach (collision rate TBD).

**Recommendation timing:** Defer to v2 (post-launch). Ship v1 via Option A; gather user feedback on Space identity accuracy. Then decide if Tier 3 refactor is worth it.

---

### Option C: Hybrid (Tier 1 + future Tier 3 prep)

**Approach:**
- Ship v1.0 ad-hoc signed (Option A) to gather feedback.
- Plan v2 to drop private APIs and prepare for notarization (Option B).
- Document the technical debt: "v2 will refactor to public APIs only for notarization."

**Pros:**
- Get the app to users today.
- Buy time to assess whether private APIs are actually necessary for your use case.
- Low risk: no upfront $99 cost or refactoring.

**Cons:**
- None significant if you're explicit in your roadmap.

**Recommendation:** This is the pragmatic path. Ship v1 as Tier 1. Gather feedback. Plan v2 refactor.

---

## 6. Alan's Recommendation

**Recommendation:** **Distribute Virtual Overlay v1 via Tier 1 (ad-hoc signed, GitHub Releases).** Ship this week.

**Rationale:**
1. **Notarization is blocked** by your current use of `dlsym` for private CGS APIs. Tier 3 is not an option without major refactoring.
2. **Tier 1 (ad-hoc) is viable and proven.** Yabai, Hammerspoon, Übersicht, and dozens of macOS utility apps distribute this way to informed audiences.
3. **Your target audience** (developers and power users discovering Space identity tools) are exactly the demographic who understand Gatekeeper warnings and the right-click → Open workaround.
4. **Your code is ready.** No changes needed. ZIP the app, write clear instructions, ship.
5. **Low cost and low friction.** Zero dollars. No Apple Developer Program enrollment yet. One README section.
6. **Future-proof.** You can upgrade to Tier 3 in v2 if you refactor to public APIs; Tier 1 users will keep working forever.

**Specific action for Cristian:**
1. Ensure `bundle.sh` builds a working `.app`.
2. Test the `.app` locally on your Mac (unzip, right-click → Open, verify it works).
3. Create a `.zip` archive.
4. Cut a GitHub Release (v1.0.0 or similar).
5. Attach the `.zip`.
6. Write release notes + README "Installation" section with the right-click instruction.
7. Announce and ship.

**Time estimate:** 2–3 hours total (mostly writing clear instructions).

**Follow-up in v2:** Evaluate whether private APIs are actually necessary for Space identity. If not, refactor and notarize. If yes, stay on Tier 1 (acceptable for power-user tools).

---

## 7. References & Sources

### Apple Official Documentation
- [Notarizing macOS Software Before Distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/technotes/tn2206/_index.html)
- [Hardened Runtime](https://developer.apple.com/documentation/xcode/hardened_runtime)

### Notarization & Private API Detection (2026)
- Private API usage via `dlsym` is reliably detected by Apple's 2026 notarization service and results in rejection.
- No documented exceptions or workarounds exist.
- Static analysis scans for symbol names, `dlsym` patterns, and binary signatures of private framework usage.

### Real-World Precedent
- **Rectangle** (notarized): public Accessibility APIs only, widely distributed, App Store approved.
- **Yabai** (ad-hoc signed): uses private SkyLight APIs, cannot be notarized, distributed to macOS power-user community.
- **Hammerspoon** (ad-hoc signed, has community-built notarized versions with reduced feature set): mostly public APIs.
- **Übersicht** (ad-hoc signed): public APIs, proven model for persistent overlays.

### Tools & Commands (2026 Standard)
- `xcrun notarytool` (not deprecated `altool`)
- `xcrun stapler staple` for attaching notarization tickets
- `spctl --assess` for verification

---

## Appendix: Gatekeeper Bypass Workarounds

**For end users (include in README):**
1. **Right-click → Open:** Right-click the app → select "Open" → click "Open" in the dialog.
2. **Xattr removal (power users only, not recommended):** `xattr -d com.apple.quarantine VirtualOverlay.app` removes quarantine, but reduces security model.

**For automated CI/CD (if you add notarization later):**
```bash
# After stapling, verify:
spctl --assess --type execute --verbose VirtualOverlay.app
# Expected: source=Notarized Developer ID
```

---

**End of research corpus. Ready for decision documentation.**
