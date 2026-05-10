---
name: "swiftpm-app-hybrid"
description: "Pattern for structuring a macOS app as SwiftPM domain packages + thin Xcode app shell"
domain: "macos-architecture"
confidence: "high"
source: "edsger-architecture-v1"
---

## Context
When building a native macOS app that needs both clean module boundaries (testability, decoupling) AND traditional app bundle features (Info.plist, entitlements, code signing, LSUIElement), neither pure Xcode groups nor pure SwiftPM executables satisfy all constraints.

## Pattern

**SwiftPM packages for domain logic + thin Xcode `.xcodeproj` app target for the bundle.**

### Structure
```
MyApp/
├── MyApp/                    # Xcode app target
│   ├── MyApp.xcodeproj/
│   ├── Sources/
│   │   └── AppDelegate.swift # Wiring only — no domain logic
│   ├── Info.plist
│   └── MyApp.entitlements
├── Packages/                 # SwiftPM local packages
│   ├── ModuleA/
│   │   ├── Package.swift
│   │   ├── Sources/
│   │   └── Tests/
│   └── ModuleB/
│       ├── Package.swift
│       ├── Sources/
│       └── Tests/
```

### Rules
1. The app target imports packages and wires concrete types. No `if` statements in the app target.
2. Each package defines protocols in its public surface. Implementations are internal or public as needed.
3. Module dependency graph must be acyclic. Draw it. Enforce it via Package.swift `dependencies`.
4. Each package is testable with `swift test` independently.

## Anti-Patterns
- Domain logic in the app target ("just this one helper...")
- Circular dependencies between packages
- One mega-package with internal "modules" (defeats the purpose)
- Using Xcode groups as "modules" (no compiler enforcement)

## When to Use
- macOS apps that need bundle features AND testable module boundaries
- Projects with 3+ domain modules
- Teams where multiple engineers own different modules
