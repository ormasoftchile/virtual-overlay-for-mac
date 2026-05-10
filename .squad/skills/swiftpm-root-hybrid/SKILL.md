---
name: "swiftpm-root-hybrid"
description: "Root SwiftPM package with library modules plus a thin executable app target for early macOS app development"
domain: "macos-architecture"
confidence: "medium"
source: "virtual-overlay-scaffold"
---

## Context

Use this pattern when the team wants compiler-enforced module boundaries and `swift build` / `swift test` from the repository root before introducing an Xcode project or signed app bundle.

## Structure

```
Package.swift
Sources/
  App/
  ModuleA/
  ModuleB/
Tests/
  ModuleATests/
  ModuleBTests/
```

## Rules

1. Keep the executable target thin: instantiate concrete types, wire streams, and start/stop services.
2. Put all domain behavior in library targets with public protocols and documented value types.
3. Keep the dependency graph acyclic and express it only in `Package.swift`.
4. Include an `Info.plist` resource for bundle metadata, but remember SwiftPM alone is not a replacement for final signing, entitlements, or distribution packaging.
5. Add one smoke or round-trip test per module immediately so target wiring stays honest.

## When to Upgrade

Move to the full SwiftPM + Xcode app-shell hybrid before distribution, notarization, custom entitlements, asset catalogs, or release signing become active work.
