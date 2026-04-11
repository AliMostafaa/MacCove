import AppKit

struct NotchDetector {

    func screenWithNotch() -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.safeAreaInsets.top > 0
        }
    }

    func hasNotch() -> Bool {
        screenWithNotch() != nil
    }

    func notchRect() -> CGRect {
        guard let screen = screenWithNotch() else {
            // Fallback: center of main screen for demo mode
            let mainFrame = NSScreen.main?.frame ?? .zero
            let w = NotchConstants.fallbackNotchWidth
            let h = NotchConstants.fallbackNotchHeight
            return CGRect(
                x: mainFrame.midX - w / 2,
                y: mainFrame.maxY - h,
                width: w,
                height: h
            )
        }

        let frame = screen.frame
        let topLeft = screen.auxiliaryTopLeftArea
        let topRight = screen.auxiliaryTopRightArea

        // The notch occupies the gap between auxiliaryTopLeftArea and auxiliaryTopRightArea
        if let left = topLeft, let right = topRight {
            let notchX = frame.origin.x + left.width
            let notchWidth = frame.width - left.width - right.width
            let notchHeight = screen.safeAreaInsets.top
            let notchY = frame.maxY - notchHeight
            return CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
        }

        // Fallback: estimate notch from safe area insets
        let safeTop = screen.safeAreaInsets.top
        let estimatedWidth: CGFloat = 200
        return CGRect(
            x: frame.midX - estimatedWidth / 2,
            y: frame.maxY - safeTop,
            width: estimatedWidth,
            height: safeTop
        )
    }

    /// Returns the center-top point of the notch in screen coordinates
    func notchCenter() -> CGPoint {
        let rect = notchRect()
        return CGPoint(x: rect.midX, y: rect.maxY)
    }

    /// Returns the size of the notch
    func notchSize() -> CGSize {
        let rect = notchRect()
        return rect.size
    }
}
