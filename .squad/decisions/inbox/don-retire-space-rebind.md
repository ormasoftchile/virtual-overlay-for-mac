# Don Decision: Retire Heuristic CGS Re-bind

**Date:** 2026-05-10T16:28:42.833-04:00  
**From:** Don  
**Status:** Proposed  
**Supersedes:** Don-8 / Space Identity v1.2 re-bind-on-first-visit behavior

## Decision

Retire the automatic re-bind logic that matched heuristic-only stored entries (`cgsSpaceID = nil`) to a fresh session CGS Space ID on first visit.

On launch, stale persisted CGS IDs may still be cleared in memory because CGS Space IDs are session-scoped. After that, any entry without a CGS ID is dormant/orphaned data. It must not be matched to or refreshed into a current CGS-backed identity.

## Rationale

The re-bind used the same heuristic matching that CGS identity was introduced to replace. In Cristian's failure case, an old entry named `third` could bind itself to the freshly detected CGS ID for Space 2, causing Space 2 to display `third` forever in that session.

Showing `UNNAMED` until the user renames each Space once under the CGS-backed identity is more honest than guessing.

## Rename invariant

Rename submit must capture the Space identity fresh at commit time, using the same `SpaceFingerprinter.currentIdentity()` path used by display refresh. The write must not use an identity cached by `WatermarkView`, `OverlayController`, or a closure captured at click-down / edit-start time.

## Follow-up, not part of this change

Dormant heuristic-only orphan entries can be garbage-collected later, but this decision does not ship a cleanup feature.
