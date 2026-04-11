import SwiftUI

enum NotchConstants {
    // Collapsed notch dimensions (approximate hardware notch)
    static let collapsedWidth: CGFloat = 200
    static let collapsedHeight: CGFloat = 32
    static let collapsedCornerRadius: CGFloat = 12

    // Expanded panel dimensions
    static let expandedWidth: CGFloat = 600
    static let expandedHeight: CGFloat = 340
    static let expandedCornerRadius: CGFloat = 24

    // Panel canvas (fixed size, larger than expanded)
    static let panelWidth: CGFloat = 720
    static let panelHeight: CGFloat = 440

    // Animation
    static let springResponse: Double = 0.45
    static let springDamping: Double = 0.74
    static let contentFadeDelay: Double = 0.1

    // Hover detection
    static let hoverPadding: CGFloat = 25
    static let collapseDelay: TimeInterval = 0.35
    static let dragExpandDelay: TimeInterval = 0.2

    // Fallback for non-notch Macs
    static let fallbackNotchWidth: CGFloat = 180
    static let fallbackNotchHeight: CGFloat = 32

    // Colors
    static let notchBackground = Color.black
    static let expandedBackground = Color(nsColor: NSColor(white: 0.08, alpha: 1.0))
    static let accentGlow = Color(red: 0.4, green: 0.6, blue: 1.0)
}

enum NotchPage: String, CaseIterable, Identifiable {
    case nowPlaying = "Now Playing"
    case shelf = "Shelf"
    case clipboard = "Clipboard"
    case widgets = "Widgets"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nowPlaying: return "music.note"
        case .shelf: return "tray.and.arrow.down"
        case .clipboard: return "doc.on.clipboard"
        case .widgets: return "square.grid.2x2"
        }
    }
}
