import SwiftUI

@Observable
final class NotchState {
    var isExpanded = false
    var isDragHovering = false
    var currentPage: NotchPage = .dashboard
    var notchRect: CGRect = .zero
    var screenWithNotch: NSScreen?
    var hasNotch: Bool = false

    // Sub-models
    let nowPlaying = NowPlayingModel()
    let shelf = ShelfService()
    let clipboard = ClipboardService()
    let settings = SettingsModel()

    // Clipboard keyboard selection
    var selectedClipboardIndex: Int = 0

    // Prevents hover monitor from auto-collapsing when opened via keyboard
    var isKeyboardPinned: Bool = false

    // Clipboard search
    var isClipboardSearchActive: Bool = false
    var clipboardSearchQuery: String = ""

    var filteredClipboardItems: [ClipboardItem] {
        let q = clipboardSearchQuery.lowercased().trimmingCharacters(in: .whitespaces)
        guard isClipboardSearchActive, !q.isEmpty else { return clipboard.items }
        return clipboard.items.filter { item in
            if let text = item.text { return text.lowercased().contains(q) }
            return "image".contains(q)
        }
    }

    // Computed
    var currentWidth: CGFloat {
        isExpanded ? NotchConstants.expandedWidth : NotchConstants.collapsedWidth
    }

    var currentHeight: CGFloat {
        isExpanded ? NotchConstants.expandedHeight : NotchConstants.collapsedHeight
    }

    var currentCornerRadius: CGFloat {
        isExpanded ? NotchConstants.expandedCornerRadius : NotchConstants.collapsedCornerRadius
    }

    func expand() {
        guard !isExpanded else { return }
        withAnimation(NotchConstants.openSpring) {
            isExpanded = true
        }
    }

    func collapse() {
        guard isExpanded else { return }
        withAnimation(NotchConstants.closeSpring) {
            isExpanded = false
        }
    }

    func toggle() {
        isExpanded ? collapse() : expand()
    }
}
