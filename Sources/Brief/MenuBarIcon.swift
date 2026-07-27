import AppKit

/// Renders the menu bar label as a template image: a solid rounded rect with
/// the text knocked out of it, Itsycal-style. Template mode keeps it legible in
/// light/dark menu bars and while highlighted.
enum MenuBarIcon {
    static func image(for text: String) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let hPadding: CGFloat = 5
        let height: CGFloat = 16
        let size = NSSize(width: ceil(textSize.width) + hPadding * 2, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            let frame = NSRect(origin: .zero, size: size)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: frame, xRadius: 4, yRadius: 4).fill()
            // Punch the text out of the pill so the menu bar shows through it.
            NSGraphicsContext.current?.cgContext.setBlendMode(.destinationOut)
            (text as NSString).draw(
                at: NSPoint(x: hPadding, y: (height - textSize.height) / 2),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = true
        return image
    }
}
