import AppKit

extension NSScreen {
    /// Whether this screen has a hardware notch (MacBook Pro 2021+)
    var hasTopNotch: Bool {
        safeAreaInsets.top > 0
    }

    /// The notch height in points
    var notchHeight: CGFloat {
        safeAreaInsets.top
    }
}

extension NSImage {
    /// Resize the image to fit within the given size
    func resized(to targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }
}
