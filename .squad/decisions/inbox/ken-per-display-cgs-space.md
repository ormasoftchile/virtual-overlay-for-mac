# Ken Decision: Per-display CGS Space Contract

**Date:** 2026-05-10T17:18:00.082-04:00  
**From:** Ken  
**Status:** Proposed correction to Space Identity v1.2

## Correction

Don's v1.2 implementation note used `CGSGetActiveSpace(connection)` as the private CGS identity source. That symbol is private/undocumented and returns the globally active Space for the currently focused display, not the current Space for an arbitrary monitor.

For multi-display correctness, Space identity capture must call the private/undocumented per-display symbol:

```c
CGSSpaceID CGSManagedDisplayGetCurrentSpace(CGSConnectionID cid, CFStringRef displayUUID);
```

The SkyLight/SLS-prefixed alias (`SLSManagedDisplayGetCurrentSpace`) is equivalent prior art and may be the exported name on some macOS releases. The `displayUUID` must be the string form of the public Core Graphics UUID returned by `CGDisplayCreateUUIDFromDisplayID()` for the specific `NSScreen` being fingerprinted.

## Contract

When creating a `SpaceIdentity` for an `NSScreen`:

1. Resolve that screen's `CGDirectDisplayID`.
2. Convert it to a display UUID string using `CGDisplayCreateUUIDFromDisplayID()`.
3. Call `CGSManagedDisplayGetCurrentSpace(connection, displayUUID)`.
4. Store the returned Space ID together with the same `displayUUID` in `SpaceIdentity`.
5. Match CGS IDs only when both `cgsSpaceID` and `displayUUID` match.

## Fallback chain

1. `CGSManagedDisplayGetCurrentSpace`/`SLSManagedDisplayGetCurrentSpace` per display.
2. `CGSGetActiveSpace`/`SLSGetActiveSpace` global fallback only when the per-display symbol is unavailable or invalid.
3. Existing public-API heuristic fingerprint when private symbols are unavailable or invalid.

Each fallback level should emit stderr diagnostics.

## Supersession

This supersedes the part of Edsger/Don v1.2 that treated `CGSGetActiveSpace` as the primary Space identity source. `CGSGetActiveSpace` remains acceptable only as a compatibility fallback and must be documented as global/focused-display behavior.
