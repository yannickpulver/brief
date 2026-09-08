import AppKit

/// Renders the day of month inside a small calendar glyph as a template image,
/// so it stays legible in light/dark menu bars and while highlighted.
enum MenuBarIcon {
    static func image(day: Int) -> NSImage {
        let width: CGFloat = 16
        let height: CGFloat = 16
        let headerHeight: CGFloat = 4
        let size = NSSize(width: width, height: height)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let text = "\(day)" as NSString
        let textSize = text.size(withAttributes: attributes)

        let image = NSImage(size: size, flipped: false) { _ in
            let frame = NSRect(origin: .zero, size: size).insetBy(dx: 0.75, dy: 0.75)
            let outline = NSBezierPath(roundedRect: frame, xRadius: 3.5, yRadius: 3.5)
            outline.lineWidth = 1.5
            NSColor.black.setStroke()
            outline.stroke()

            let header = NSRect(x: frame.minX, y: frame.maxY - headerHeight, width: frame.width, height: headerHeight)
            NSBezierPath(rect: header).addClip()
            NSColor.black.setFill()
            outline.fill()
            NSGraphicsContext.current?.cgContext.resetClip()

            let bodyHeight = frame.height - headerHeight
            text.draw(
                at: NSPoint(x: (width - textSize.width) / 2, y: frame.minY + (bodyHeight - textSize.height) / 2 + 0.5),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = true
        return image
    }
}
