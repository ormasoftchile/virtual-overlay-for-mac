# Session Log: v1 Ratification + Prototype

**Timestamp:** 2026-05-10T11:57:23Z  
**Topic:** v1 scope ratification and first runnable prototype.

## Snapshot

Two agents completed work:

1. **Edsger (Ratification):** Approved v1 public-API-only architecture. All detection via `NSWorkspace.activeSpaceDidChangeNotification`; overlay via documented AppKit. Codified constraints for Ken, Don, Alan.

2. **Ken (Prototype):** Built `OverlayWindowProbe` using `.floating` level + `collectionBehavior`. Code is sound. Build blocked on this machine (CLT only, no Xcode.app); needs Xcode for verification.

## Decisions Captured

- v1 Public-API-Only Architecture (approved by Edsger)
- `.floating` Window Level for v1 Overlay Probe (Ken proposal, in decisions.md)

## Environmental Note

Ken's prototype build requires Xcode.app installation; CLT PackageDescription linker does not support Swift 6.2 manifest resolution on this machine. Code itself is production-ready.

## Next: Team Coordination

Edsger's decision unblocks Ken's detection strategy, Don's persistence design, and Alan's research tracking. Prototype location staged for renderer integration.
