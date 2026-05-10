# Susan Decision: Programmatic Typographic App Icon

**Date:** 2026-05-10T17:26:50.686-04:00  
**From:** Susan  
**Status:** Proposed

## Decision

Virtual Overlay's app icon is a restrained typographic marker: a centered SF Pro ultra-light `V` framed by geometric bracket rules on a near-black macOS squircle.

## Key visual choices

- Canvas: 1024×1024, with the visible squircle inset to 824×824 and a 184 px corner radius.
- Background: `#111416`, a quiet near-black with a slight blue-green cast.
- Foreground: `#F4F1EA` at 94% opacity for legibility.
- Type: system SF Pro Display via `NSFont.systemFont(ofSize: 500, weight: .ultraLight)`.
- Frame: two 16 px bracket rules, x = 284 and x = 740, y = 304…720, with 44 px returns.
- No gradients, color accents, skeuomorphic objects, or screen/window metaphors.

## Rationale

The product itself is a persistent text watermark for spatial orientation. A pure typographic `V` framed like architectural signage rhymes with that watermark while remaining durable in Finder and Dock contexts. At small sizes, the V silhouette and bracket stems survive as a quiet orientation mark rather than a decorative badge.

## Source of truth

The icon is generated in code at `Tools/IconGenerator/`. Generated assets are checked in at `Resources/AppIcon.iconset/` and `Resources/AppIcon.icns` so fresh clones do not need to run the generator before bundling.
