import SwiftUI

/// Morphing notch shape with hardware-style "ears" that blend into the screen edge.
/// Uses arc-tangent corners (circular, not quadratic) and cubic-bezier ears for
/// the premium organic feel of a machined surface.
struct NotchShapeWithEars: Shape, Animatable {
    var progress: CGFloat // 0 = collapsed, 1 = expanded

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = lerp(NotchConstants.collapsedWidth, NotchConstants.expandedWidth, progress)
        let h = lerp(NotchConstants.collapsedHeight, NotchConstants.expandedHeight, progress)
        let r = lerp(NotchConstants.collapsedCornerRadius, NotchConstants.expandedCornerRadius, progress)

        // Ear size: how far the transition curve extends horizontally past the notch edge
        let earSize: CGFloat = lerp(9, 18, progress)

        let cx = rect.midX
        let x = cx - w / 2
        let y = rect.minY

        var path = Path()

        // ── Left ear ──────────────────────────────────────────────────────────
        // Start on screen top, just outside the notch left edge
        path.move(to: CGPoint(x: x - earSize, y: y))

        // Cubic-bezier ear: tangent exits horizontally, enters vertically.
        // The asymmetric control points create a graceful S-like transition
        // that matches the hardware notch's machined chamfer.
        path.addCurve(
            to:       CGPoint(x: x,             y: y + earSize),
            control1: CGPoint(x: x - earSize * 0.14, y: y),
            control2: CGPoint(x: x,             y: y + earSize * 0.14)
        )

        // Left side straight down
        path.addLine(to: CGPoint(x: x, y: y + h - r))

        // Bottom-left corner — circular arc via tangent method.
        // addArc(tangent1End:tangent2End:radius:) draws a true arc inscribed
        // between the two line segments, giving perfectly circular corners
        // (identical to how Apple draws UIBezierPath rounded rects).
        path.addArc(
            tangent1End: CGPoint(x: x,     y: y + h),
            tangent2End: CGPoint(x: x + r, y: y + h),
            radius: r
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: x + w - r, y: y + h))

        // Bottom-right corner — circular arc
        path.addArc(
            tangent1End: CGPoint(x: x + w,     y: y + h),
            tangent2End: CGPoint(x: x + w,     y: y + h - r),
            radius: r
        )

        // Right side straight up
        path.addLine(to: CGPoint(x: x + w, y: y + earSize))

        // ── Right ear ─────────────────────────────────────────────────────────
        // Mirror of the left ear
        path.addCurve(
            to:       CGPoint(x: x + w + earSize,        y: y),
            control1: CGPoint(x: x + w,                  y: y + earSize * 0.14),
            control2: CGPoint(x: x + w + earSize * 0.14, y: y)
        )

        path.closeSubpath()
        return path
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

/// Flat-top notch shape (no ears). Kept for reference / non-notch Macs.
struct NotchShape: Shape, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = lerp(NotchConstants.collapsedWidth, NotchConstants.expandedWidth, progress)
        let h = lerp(NotchConstants.collapsedHeight, NotchConstants.expandedHeight, progress)
        let r = lerp(NotchConstants.collapsedCornerRadius, NotchConstants.expandedCornerRadius, progress)

        let x = rect.midX - w / 2
        let y = rect.minY

        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + w, y: y))
        path.addLine(to: CGPoint(x: x + w, y: y + h - r))
        path.addArc(
            tangent1End: CGPoint(x: x + w, y: y + h),
            tangent2End: CGPoint(x: x + w - r, y: y + h),
            radius: r
        )
        path.addLine(to: CGPoint(x: x + r, y: y + h))
        path.addArc(
            tangent1End: CGPoint(x: x, y: y + h),
            tangent2End: CGPoint(x: x, y: y + h - r),
            radius: r
        )
        path.addLine(to: CGPoint(x: x, y: y))
        path.closeSubpath()
        return path
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}
