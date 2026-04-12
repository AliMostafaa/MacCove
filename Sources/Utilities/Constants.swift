import SwiftUI

enum NotchConstants {
    // Collapsed notch dimensions (approximate hardware notch)
    static let collapsedWidth: CGFloat = 200
    static let collapsedHeight: CGFloat = 32
    static let collapsedCornerRadius: CGFloat = 12

    // Expanded panel dimensions
    static let expandedWidth: CGFloat = 600
    static let expandedHeight: CGFloat = 360
    static let expandedCornerRadius: CGFloat = 24

    // Panel canvas (fixed size, larger than expanded)
    static let panelWidth: CGFloat = 720
    static let panelHeight: CGFloat = 460

    // MARK: - Animation

    /// Opening: organic, slight bounce — feels alive
    static let openSpring  = Animation.spring(response: 0.46, dampingFraction: 0.72)
    /// Closing: decisive, well-damped — shape and content finish together
    static let closeSpring = Animation.spring(response: 0.34, dampingFraction: 0.90)
    /// Content entrance (kept for legacy call-sites)
    static let contentEntrance = Animation.spring(response: 0.38, dampingFraction: 0.84)
    /// Tab pill slide: very snappy
    static let tabSpring = Animation.spring(response: 0.26, dampingFraction: 0.80)

    static let contentFadeDelay: Double = 0.07

    // Hover detection
    static let hoverPadding: CGFloat = 25
    static let collapseDelay: TimeInterval = 0.35
    static let dragExpandDelay: TimeInterval = 0.2

    // Fallback for non-notch Macs
    static let fallbackNotchWidth: CGFloat = 180
    static let fallbackNotchHeight: CGFloat = 32

    // MARK: - Colors

    static let notchBackground = Color.black
    static let expandedBackground = Color(nsColor: NSColor(white: 0.07, alpha: 1.0))
    static let accentGlow = Color(red: 0.45, green: 0.62, blue: 1.0)
    static let surfaceOverlay = Color.white.opacity(0.055)
    static let surfaceOverlayHover = Color.white.opacity(0.10)
}

enum NotchPage: String, CaseIterable, Identifiable {
    case dashboard = "Home"
    case shelf     = "Shelf"
    case clipboard = "Clipboard"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .shelf:     return "tray.and.arrow.down"
        case .clipboard: return "doc.on.clipboard"
        }
    }
}
