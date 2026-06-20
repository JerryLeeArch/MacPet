import AppKit

@MainActor
enum PlaceholderPetImage {
    static func make(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let bodyRect = NSRect(x: 36, y: 34, width: 108, height: 104)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 34, yRadius: 34)
        NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.20, alpha: 0.92).setFill()
        bodyPath.fill()

        let eyeSize = NSSize(width: 10, height: 14)
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: NSRect(x: 74, y: 86, width: eyeSize.width, height: eyeSize.height)).fill()
        NSBezierPath(ovalIn: NSRect(x: 96, y: 86, width: eyeSize.width, height: eyeSize.height)).fill()

        NSColor(calibratedRed: 0.40, green: 0.78, blue: 0.64, alpha: 0.95).setFill()
        NSBezierPath(ovalIn: NSRect(x: 84, y: 64, width: 12, height: 8)).fill()

        image.unlockFocus()
        return image
    }
}
