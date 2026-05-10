# Identity Probe Results — Public API Space Signals

**Date:** 2026-05-10T15:14:32.937-04:00  
**Agent:** Ken — macOS Specialist  
**Scope:** Public AppKit/Core Graphics probes only. No CGS/SkyLight/private imports.

---

## Summary

All five probes were built as standalone SwiftPM executables under `Prototypes/IdentityProbes/` and run with `swift build && swift run` from each probe folder. Baseline runs for probes 3 and 5 were non-interactive, so they validate idle behavior and executable correctness, not manual Space-switch reliability.

Most important implementation finding for Don: use `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` as the collection call, then derive the fingerprint from **layer 0 application windows only**. The option set alone is not clean enough; menu bar, Control Center, Dock, and other system surfaces still appear unless filtered.

---

## Probe 1 — Display UUID Stability

### Question
Can we reliably extract `CGDisplayCreateUUIDFromDisplayID` on the local machine without crashing, and is it non-empty/stable across app restarts?

### What I built
`Prototypes/IdentityProbes/probe-1-display-uuid-stability/`

The probe prints every `NSScreen` with `localizedName`, `displayID`, Core Graphics display UUID, `frame`, and `visibleFrame`.

### What I observed
Result file: `Prototypes/IdentityProbes/probe-1-display-uuid-stability/results-2026-05-10.txt`

Excerpt:

```text
Screen count: 1
screen[0] name="Built-in Retina Display" displayID=1 uuid=37D8832A-2D66-02CA-B9F7-8F30A301B230 frame=(0.0, 0.0, 1680.0, 1050.0) visibleFrame=(0.0, 62.0, 1680.0, 958.0)
```

I ran this probe multiple times while iterating on the package; the built-in display UUID remained the same and was non-empty. I could not validate reboot stability or external display unplug/replug in this non-interactive run because only one built-in display was connected.

### Verdict
⚠️ Partially confirms Alan's assumption.

The public API works, does not crash, and returns a stable non-empty UUID across app restarts on the built-in display. External-display and reboot stability still need Cristian to re-run the probe manually.

### Recommendation for Don
Keep `displayUUID` as the primary hardware anchor. Model it as optional/failable at collection time anyway, because display enumeration can change during sleep/wake, unplug/replug, or clamshell transitions.

---

## Probe 2 — Window List Scope

### Question
Does `CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)` include windows from all Spaces or only the active visible Space?

### What I built
`Prototypes/IdentityProbes/probe-2-window-list-scope/`

The probe prints every `.optionOnScreenOnly` window with owning bundle ID, process name, title, layer, bounds, and the display whose Core Graphics bounds it intersects.

### What I observed
Result file: `Prototypes/IdentityProbes/probe-2-window-list-scope/results-2026-05-10.txt`

Excerpt:

```text
Window count (.optionOnScreenOnly): 26
[10] bundle=com.microsoft.VSCodeInsiders owner="Code - Insiders" title="<untitled>" layer=0 bounds=(0.0, 30.0, 1680.0, 957.0)
[11] bundle=com.googlecode.iterm2 owner="iTerm2" title="<untitled>" layer=0 bounds=(683.0, 30.0, 997.0, 764.0)
[12] bundle=com.apple.AppStore owner="App Store" title="<untitled>" layer=0 bounds=(144.0, 44.0, 1180.0, 724.0)
[17] bundle=com.apple.Safari owner="Safari" title="<untitled>" layer=0 bounds=(0.0, 30.0, 1680.0, 957.0)
[20] bundle=com.apple.finder owner="Finder" title="<untitled>" layer=0 bounds=(407.0, 30.0, 920.0, 883.0)
```

The call returns a current on-screen stack including menu bar/control center/Dock/wallpaper surfaces and visible app windows. Window titles were mostly hidden as `<untitled>`, which is expected on modern macOS without Screen Recording permission.

Because this run was non-interactive and I did not switch between prepared Spaces with known unique apps, it does **not** conclusively answer whether inactive-Space windows are excluded. The probe is ready for Cristian to re-run on two Spaces with distinctive apps.

### Verdict
⚠️ Partially confirms Alan's assumption.

The API returns useful active display/window data and can be called safely, but the critical all-Spaces-vs-active-Space question still requires the manual two-Space comparison described in the README.

### Recommendation for Don
Implement the window-signature collector behind a strategy interface and treat it as an eventually-correct heuristic. Do not depend on window titles unless Screen Recording permission is intentionally requested; prefer bundle ID + owner + layer + coarse bounds. Keep a feature flag or logging hook so we can disable window signature if manual reruns prove `.optionOnScreenOnly` leaks inactive Spaces.

---

## Probe 3 — Space Change Notification Info

### Question
Does `NSWorkspace.activeSpaceDidChangeNotification` carry identifying info, and do immediate window-list snapshots correlate with Space changes?

### What I built
`Prototypes/IdentityProbes/probe-3-space-change-notification-info/`

The probe subscribes to `NSWorkspace.activeSpaceDidChangeNotification`, logs timestamp, full `userInfo`, and a `.optionOnScreenOnly` window snapshot after each notification. It runs for 60 seconds.

### What I observed
Result file: `Prototypes/IdentityProbes/probe-3-space-change-notification-info/results-2026-05-10.txt`

Excerpt:

```text
Run duration: 60 seconds
Initial snapshot:
initial: windowCount=26
initial[10] owner="Code - Insiders" title="<untitled>" layer=0
initial[11] owner="iTerm2" title="<untitled>" layer=0
initial[12] owner="App Store" title="<untitled>" layer=0
Finished. Notification count: 0. Elapsed: 60.056s
```

No notifications fired during the idle non-interactive baseline. That is correct idle behavior, but it does not validate `userInfo` contents or snapshot correlation during actual Space switches.

### Verdict
⚠️ Inconclusive for Alan's notification-sequence assumption.

The probe builds and is ready; idle run produced no false-positive notifications. Manual Space switching is still required to inspect `userInfo` and ordinal inference behavior.

### Recommendation for Don
Assume the notification is a trigger only, not an identity source. Build SpaceDetection so each notification schedules a debounced snapshot read after a short delay, rather than trying to read an ID from `userInfo`.

---

## Probe 4 — Minimized and Hidden Windows

### Question
Which window-list option set produces the best stable per-Space signature, and do minimized/hidden windows require `.optionAll`?

### What I built
`Prototypes/IdentityProbes/probe-4-minimized-and-hidden-windows/`

The probe compares:

1. `[.optionOnScreenOnly]`
2. `[.optionAll]`
3. `[.optionOnScreenOnly, .excludeDesktopElements]`

It prints total counts, layer-0 counts, and example windows.

### What I observed
Result file: `Prototypes/IdentityProbes/probe-4-minimized-and-hidden-windows/results-2026-05-10.txt`

Excerpts:

```text
--- onScreenOnly ---
count=26 layer0Count=11
```

```text
--- all ---
count=91 layer0Count=56
[0] bundle=com.apple.coreservices.uiagent owner="CoreServicesUIAgent" ... layer=3 alpha=0.1106...
[1] bundle=com.apple.AMSUIPaymentViewService owner="AMSUIPaymentViewService_macOS" ... layer=0
[2] bundle=com.apple.AuthKitUI.AKAuthorizationRemoteViewServic" ... layer=0
```

```text
--- onScreenOnlyExcludeDesktopElements ---
count=22 layer0Count=11
[0] bundle=com.apple.controlcenter owner="Control Center" ... layer=25
[8] bundle=<no-bundle-id> owner="Window Server" title="Menubar" layer=24
[9] bundle=com.apple.dock owner="Dock" ... layer=20
[layer0 0] bundle=com.microsoft.VSCodeInsiders owner="Code - Insiders" ... layer=0
[layer0 1] bundle=com.googlecode.iterm2 owner="iTerm2" ... layer=0
[layer0 2] bundle=com.apple.AppStore owner="App Store" ... layer=0
```

`.optionAll` is much noisier and includes hidden/offscreen service windows. `.excludeDesktopElements` removes wallpaper/desktop negatives but still leaves menu bar, Control Center, Dock, and other non-app surfaces. The cleanest baseline is therefore the exclude-desktop option set plus a layer-0 application-window filter.

The non-interactive run did not minimize a known window, so it does not prove minimized-window behavior directly. However, the `.optionAll` result demonstrates why using all windows for identity would import substantial noise.

### Verdict
✅ Confirms Alan's caution that window signatures are volatile; ⚠️ refines the implementation detail.

Alan's suggested option set is the right starting call, but it is not sufficient by itself. Don should add post-filters.

### Recommendation for Don
Use:

```swift
CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
```

Then fingerprint only windows where `kCGWindowLayer == 0`, owner/bundle is present, bounds are non-empty, and known system/service bundles are ignored if they still leak in. Do **not** use `.optionAll` for the primary signature. If minimized-window resilience is needed later, collect `.optionAll` only as a secondary repair signal with aggressive filtering.

---

## Probe 5 — Sequoia Notification Reliability

### Question
Does `NSWorkspace.activeSpaceDidChangeNotification` fire reliably on current macOS/Sequoia-style systems under stress, and does it duplicate or miss events?

### What I built
`Prototypes/IdentityProbes/probe-5-sequoia-notification-reliability/`

The probe logs OS version, initial frontmost app, initial window count, then every active-Space notification with timestamp, delta, frontmost app, window count, and `userInfo`. It runs for 60 seconds.

### What I observed
Result file: `Prototypes/IdentityProbes/probe-5-sequoia-notification-reliability/results-2026-05-10.txt`

Excerpt:

```text
OS: Version 26.3.1 (a) (Build 25D771280a)
Initial frontmostApp=Code - Insiders pid=59265
Initial windowCount=26
Finished. Notification count: 0. Elapsed: 60.057s
```

No idle duplicates or false positives fired. This does not validate rapid Space switching, fullscreen enter/exit, or display hotplug behavior because the run was non-interactive.

### Verdict
⚠️ Partially confirms notification sanity only.

The notification observer is safe and quiet when idle. Manual stress is still needed before claiming reliability.

### Recommendation for Don
Debounce notifications and make snapshot processing idempotent. Expect duplicate/missed notifications until Cristian reruns the stress probe manually. A safe v1 shape is: notification/event source → short debounce → collect display/window signals → fuzzy match → publish only if identity changed or confidence improved.

---

## Public/Private API Notes

- `NSScreen`, `NSWorkspace.activeSpaceDidChangeNotification`, `CGWindowListCopyWindowInfo`, `CGDisplayCreateUUIDFromDisplayID`, and `NSRunningApplication` are public APIs.
- No private CGS/SkyLight APIs were imported or called.
- `CGWindowListCopyWindowInfo` is public, but window title visibility is privacy-sensitive on modern macOS and may be blank without Screen Recording permission.

---

## Manual Follow-ups for Cristian

1. Re-run probe 1 after reboot and after external display unplug/replug.
2. Re-run probe 2 on two Spaces with distinctive apps to conclusively answer active-Space-only vs all-Spaces behavior.
3. Re-run probe 3 while switching Spaces in the exact sequence Alan listed: 1 → 2 → 3 → 1 → 4.
4. Re-run probe 4 before and after minimizing a known app window.
5. Re-run probe 5 while rapidly switching Spaces, entering/exiting fullscreen apps, and hotplugging a display if available.
