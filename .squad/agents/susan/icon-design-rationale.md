# App Icon Design Rationale

## Concept

The icon is an infrastructural typographic marker: a quiet bracketed `V` standing for Virtual Overlay, drawn like architectural signage rather than a consumer badge. It is not an illustration, not a colorful desktop icon, and not a metaphorical screen/window graphic; it is the same ambient labeling system as the watermark, compressed into one durable mark.

## Composition

The source canvas is 1024×1024. The visible macOS app-icon body is a 824×824 rounded square inset 100 px from every edge, with a 184 px corner radius. The mark is centered optically inside that body. The `V` is set at 500 px on the 1024 canvas, centered on x = 512 with its cap-height block centered around y = 514. Two bracket rules sit at x = 284 and x = 740, from y = 304 to y = 720, with 44 px horizontal returns and a 16 px stroke width. This gives the large icon an architectural frame while preserving a simple three-stroke silhouette at small sizes.

## Type choice

The letter is SF Pro Display via the system font, weight `.ultraLight`, with no external dependency. Tracking is not applied because the icon uses a single character; the restraint comes from weight and spacing between the bracket frame and the glyph. The bracket rules are geometric rather than typed so they remain precise and survive raster reduction.

## Palette

Background body: `#111416` (sRGB 17, 20, 22), a near-black with a slight blue-green architectural cast. Foreground: `#F4F1EA` (sRGB 244, 241, 234) at 94% opacity for high contrast. Edge rule: `#FFFFFF` at 7% opacity, a barely-there bevel line to separate the squircle from dark desktops. Shadow: black at 18% opacity, soft and minimal. There is no gradient.

## Reasoning at small sizes

At 16×16 the ultra-light nuances disappear, so the icon depends on the centered `V` silhouette and the two vertical bracket stems. The bracket returns collapse into small caps that still read as a framed marker, matching the app's core idea: a sparse label that orients the user without becoming decoration.
