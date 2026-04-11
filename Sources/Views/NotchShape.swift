import SwiftUI

/// A custom shape that morphs between the collapsed notch and expanded panel.
/// The shape is drawn from the top-center, expanding outward and downward.
struct NotchShape: Shape, Animatable {
    var progress: CGFloat // 0 = collapsed, 1 = expanded

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let collapsedW = NotchConstants.collapsedWidth
        let collapsedH = NotchConstants.collapsedHeight
        let expandedW = NotchConstants.expandedWidth
        let expandedH = NotchConstants.expandedHeight

        let collapsedR = NotchConstants.collapsedCornerRadius
        let expandedR = NotchConstants.expandedCornerRadius

        // Interpolate dimensions
        let w = lerp(collapsedW, expandedW, progress)
        let h = lerp(collapsedH, expandedH, progress)
        let r = lerp(collapsedR, expandedR, progress)

        // Center horizontally in the rect, anchor to top
        let x = rect.midX - w / 2
        let y = rect.minY

        // Create the notch path with rounded bottom corners and flat top
        var path = Path()

        // Top-left corner (straight, flush with screen top)
        path.move(to: CGPoint(x: x, y: y))

        // Top edge
        path.addLine(to: CGPoint(x: x + w, y: y))

        // Right side going down
        path.addLine(to: CGPoint(x: x + w, y: y + h - r))

        // Bottom-right rounded corner
        path.addQuadCurve(
            to: CGPoint(x: x + w - r, y: y + h),
            control: CGPoint(x: x + w, y: y + h)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: x + r, y: y + h))

        // Bottom-left rounded corner
        path.addQuadCurve(
            to: CGPoint(x: x, y: y + h - r),
            control: CGPoint(x: x, y: y + h)
        )

        // Left side going up
        path.addLine(to: CGPoint(x: x, y: y))

        path.closeSubpath()
        return path
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

/// A more organic notch shape with curved "ears" that blend into the screen top,
/// similar to the hardware notch appearance.
struct NotchShapeWithEars: Shape, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let collapsedW = NotchConstants.collapsedWidth
        let collapsedH = NotchConstants.collapsedHeight
        let expandedW = NotchConstants.expandedWidth
        let expandedH = NotchConstants.expandedHeight

        let collapsedR = NotchConstants.collapsedCornerRadius
        let expandedR = NotchConstants.expandedCornerRadius

        let w = lerp(collapsedW, expandedW, progress)
        let h = lerp(collapsedH, expandedH, progress)
        let r = lerp(collapsedR, expandedR, progress)

        // Ear curve size (the small curve connecting notch to screen edge)
        let earSize: CGFloat = lerp(8, 14, progress)

        let cx = rect.midX
        let x = cx - w / 2
        let y = rect.minY

        var path = Path()

        // Start from far left with the ear curve
        path.move(to: CGPoint(x: x - earSize, y: y))

        // Left ear curve (curves down into the notch)
        path.addQuadCurve(
            to: CGPoint(x: x, y: y + earSize),
            control: CGPoint(x: x, y: y)
        )

        // Left side down
        path.addLine(to: CGPoint(x: x, y: y + h - r))

        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: x + r, y: y + h),
            control: CGPoint(x: x, y: y + h)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: x + w - r, y: y + h))

        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: x + w, y: y + h - r),
            control: CGPoint(x: x + w, y: y + h)
        )

        // Right side up
        path.addLine(to: CGPoint(x: x + w, y: y + earSize))

        // Right ear curve
        path.addQuadCurve(
            to: CGPoint(x: x + w + earSize, y: y),
            control: CGPoint(x: x + w, y: y)
        )

        path.closeSubpath()
        return path
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}
