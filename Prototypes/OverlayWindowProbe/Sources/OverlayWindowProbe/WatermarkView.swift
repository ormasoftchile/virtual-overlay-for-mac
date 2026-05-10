import AppKit

final class WatermarkView: NSView {
    private let text = "PROTOTYPE"
    private let padding: CGFloat = 96

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let baseFontSize: CGFloat = 240
        let maxSize = NSSize(
            width: max(1, bounds.width - (padding * 2)),
            height: max(1, bounds.height - (padding * 2))
        )
        let baseAttributed = attributedString(fontSize: baseFontSize)
        let baseSize = baseAttributed.size()
        let scale = min(1, maxSize.width / baseSize.width, maxSize.height / baseSize.height)
        let attributed = attributedString(fontSize: baseFontSize * scale)
        let size = attributed.size()
        let origin = NSPoint(
            x: bounds.maxX - size.width - padding,
            y: bounds.minY + padding
        )

        attributed.draw(at: origin)
    }

    private func attributedString(fontSize: CGFloat) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .ultraLight)
        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.white.withAlphaComponent(0.10),
                .kern: fontSize * 0.05
            ]
        )
    }
}
