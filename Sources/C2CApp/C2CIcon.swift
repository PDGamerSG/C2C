import AppKit

/// Two offset C-shaped clips: one captured, one ready to paste.
@MainActor
enum C2CIcon {
    private static func clipPath(offset: NSPoint) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: offset.x + 8, y: offset.y))
        path.line(to: NSPoint(x: offset.x + 4, y: offset.y))
        path.curve(to: NSPoint(x: offset.x, y: offset.y + 4),
                   controlPoint1: NSPoint(x: offset.x + 1.5, y: offset.y),
                   controlPoint2: NSPoint(x: offset.x, y: offset.y + 1.5))
        path.line(to: NSPoint(x: offset.x, y: offset.y + 7))
        path.curve(to: NSPoint(x: offset.x + 4, y: offset.y + 11),
                   controlPoint1: NSPoint(x: offset.x, y: offset.y + 9.5),
                   controlPoint2: NSPoint(x: offset.x + 1.5, y: offset.y + 11))
        path.line(to: NSPoint(x: offset.x + 8, y: offset.y + 11))
        path.lineWidth = 2.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        return path
    }

    static func drawMark(in rect: NSRect, first: NSColor, second: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.translateBy(x: rect.minX, y: rect.maxY)
        NSGraphicsContext.current?.cgContext.scaleBy(x: rect.width / 24, y: -rect.height / 24)
        first.setStroke()
        clipPath(offset: NSPoint(x: 4, y: 4)).stroke()
        second.setStroke()
        clipPath(offset: NSPoint(x: 12, y: 9)).stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 19, height: 19), flipped: false) { rect in
            MainActor.assumeIsolated { drawMark(in: rect, first: .black, second: .black) }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "C2C Clipboard"
        return image
    }

    static func drawApplicationIcon(in rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.scaleBy(x: rect.width / 1_024, y: rect.height / 1_024)
        let tile = NSBezierPath(roundedRect: NSRect(x: 88, y: 88, width: 848, height: 848), xRadius: 190, yRadius: 190)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.shadowBlurRadius = 24
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.set()
        NSColor(calibratedRed: 0.05, green: 0.27, blue: 0.32, alpha: 1).setFill()
        tile.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: NSColor(calibratedRed: 0.03, green: 0.23, blue: 0.29, alpha: 1),
                   ending: NSColor(calibratedRed: 0.06, green: 0.56, blue: 0.56, alpha: 1))!.draw(in: tile, angle: 65)
        drawMark(in: NSRect(x: 104, y: 104, width: 816, height: 816),
                 first: NSColor(calibratedWhite: 0.98, alpha: 1),
                 second: NSColor(calibratedRed: 0.55, green: 0.97, blue: 0.83, alpha: 1))
        NSGraphicsContext.restoreGraphicsState()
    }
}
