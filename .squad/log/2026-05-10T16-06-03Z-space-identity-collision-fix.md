# Session Log: Space Identity Collision Fix (Don-7)

**Date:** 2026-05-10T16:06:03Z  
**Agent:** Don  
**Topic:** Space identity v1.1 — collision fix

## Problem

Two distinct Spaces could collide on the same name because the v1 identity shape was too sparse (displayUUID + windowSignature + ordinal only). In production with multiple displays and volatile window sets, this led to false positives in fuzzy matching.

## Solution

Strengthened the fingerprint shape:
- `displayUUID`
- `windowSignature`
- `frontmostAppBundleID` ← **NEW**
- `windowCount` ← **NEW**
- `windowGeometrySignature` ← **NEW**
- `ordinal`
- `firstSeen`

Tightened the matcher:
- Exact signal equality wins immediately.
- Fuzzy matching allowed only when: same display, same frontmost app, ≥0.8 Jaccard similarity over visible window bundle IDs, and best candidate beats runner-up by ≥0.15.
- Ambiguity returns nil → watermark shows "UNNAMED" → user renames via Option-click.

## Migration

Pre-v1.1 JSON entries still decode (Codable tolerant load) but with new fields defaulted. They normally fail to fuzzy-match richer current fingerprints and become orphaned. This prevents persistent collisions. Users re-create labels independently via rename.

## Validation

18 tests, 0 failures. All edge cases covered.
