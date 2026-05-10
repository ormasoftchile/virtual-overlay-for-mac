# Session Log — Private API Pivot (v1.2 Decision)

**Timestamp:** 2026-05-10T16:15:05.647-04:00  
**Topic:** Lifted public-API-only constraint; private CGS now in scope for Space identity.

## What happened

Edsger completed architecture review of recurring Space-identity collision problem. After empirical validation (Cristian hit the same collision twice) and research confirmation (Ken's probe-2 showed `CGWindowListCopyWindowInfo` does not scope to active Space), decision made to introduce `CGSGetActiveSpace` as a session-scoped identity anchor.

**Key finding:** No combination of public signals distinguishes two Spaces that look identical to the windowing server. The public-API approach (v1 ratification) was correct given available information but underestimated the within-session disambiguation value of the private API.

## Triggers

- **Cristian's empirical collisions:** Hit same Space-lookup collision twice (same app foreground on different Spaces).
- **Ken's probe-2 finding:** `CGWindowListCopyWindowInfo([.optionOnScreenOnly])` does not filter to active Space; returns same window set for sibling Spaces.
- **Don's v1.1 enrichment:** Added `frontmostAppBundleID`, `windowCount`, `windowGeometrySignature` but collision persists because all discriminators identical on same-foreground-app siblings.

## Path forward

Don-8 to implement v1.2:
- `CGSGetActiveSpace` via `dlsym` (no link-time dependency).
- Session-scoped numeric ID as highest-priority match tier.
- Automatic fallback to public-API path if symbols unavailable.
- Backward-compatible JSON schema migration.

**Expected outcome:** Within-session collisions eliminated. Session-specific names solid. Identity re-binds on first post-launch visit per Space.

---
