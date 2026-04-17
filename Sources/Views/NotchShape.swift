import SwiftUI

/// Morphing notch shape with hardware-style "ears" that blend into the screen edge.
/// Uses arc-tangent corners (circular, not quadratic) and cubic-bezier ears for
/// the premium organic feel of a machined surface.
///
/// One unified motion: width and height grow together on the same curve.
/// Apple never splits axes — everything moves as one.
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

        let earSize: CGFloat = lerp(9, 18, progress)

        let cx = rect.midX
        let x = cx - w / 2
        let y = rect.minY

        var path = Path()

        // ── Left ear ──────────────────────────────────────────────────────────
        path.move(to: CGPoint(x: x - earSize, y: y))

        path.addCurve(
            to:       CGPoint(x: x,                  y: y + earSize),
            control1: CGPoint(x: x - earSize * 0.14, y: y),
            control2: CGPoint(x: x,                  y: y + earSize * 0.14)
        )

        // Left side straight down
        path.addLine(to: CGPoint(x: x, y: y + h - r))

        // Bottom-left corner
        path.addArc(
            tangent1End: CGPoint(x: x,     y: y + h),
            tangent2End: CGPoint(x: x + r, y: y + h),
            radius: r
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: x + w - r, y: y + h))

        // Bottom-right corner
        path.addArc(
            tangent1End: CGPoint(x: x + w,     y: y + h),
            tangent2End: CGPoint(x: x + w,     y: y + h - r),
            radius: r
        )

        // Right side straight up
        path.addLine(to: CGPoint(x: x + w, y: y + earSize))

        // ── Right ear ─────────────────────────────────────────────────────────
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

/// Rounded-rect shape anchored to a bottom corner. No ears — it's a floating widget.
struct CornerNotchShape: Shape, Animatable {
    var progress: CGFloat
    var isLeading: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = lerp(NotchConstants.collapsedWidth,      NotchConstants.expandedWidth,      progress)
        let h = lerp(NotchConstants.collapsedHeight,     NotchConstants.expandedHeight,     progress)
        let r = lerp(NotchConstants.collapsedCornerRadius, NotchConstants.expandedCornerRadius, progress)
        let x: CGFloat = isLeading ? rect.minX : rect.maxX - w
        let y: CGFloat = rect.maxY - h
        return Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

/// Unified shape that delegates to the right variant based on position.
/// Use this everywhere instead of calling NotchShapeWithEars or CornerNotchShape directly.
struct AdaptiveNotchShape: Shape, Animatable {
    var progress: CGFloat
    var position: NotchPosition

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        switch position {
        case .topCenter:
            return NotchShapeWithEars(progress: progress).path(in: rect)
        case .bottomLeft:
            return CornerNotchShape(progress: progress, isLeading: true).path(in: rect)
        case .bottomRight:
            return CornerNotchShape(progress: progress, isLeading: false).path(in: rect)
        }
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
