import AppKit
import SwiftUI

final class NotchWindowController {
    private let state: NotchState
    private(set) var panel: NotchPanel!

    init(state: NotchState) {
        self.state = state
        setupPanel()
    }

    private func panelOrigin(for screen: NSScreen) -> CGPoint {
        let sf = screen.frame
        let pw = NotchConstants.panelWidth
        let ph = NotchConstants.panelHeight
        switch state.settings.notchPosition {
        case .topCenter:
            return CGPoint(x: sf.midX - pw / 2, y: sf.maxY - ph)
        case .bottomLeft:
            return CGPoint(x: sf.minX, y: sf.minY)
        case .bottomRight:
            return CGPoint(x: sf.maxX - pw, y: sf.minY)
        }
    }

    func repositionPanel() {
        let screen = state.screenWithNotch ?? NSScreen.main!
        let origin = panelOrigin(for: screen)
        panel.setFrame(NSRect(origin: origin,
                              size: CGSize(width: NotchConstants.panelWidth,
                                           height: NotchConstants.panelHeight)),
                       display: true)
    }

    private func setupPanel() {
        let screen = state.screenWithNotch ?? NSScreen.main!
        let origin = panelOrigin(for: screen)
        let contentRect = NSRect(origin: origin,
                                 size: CGSize(width: NotchConstants.panelWidth,
                                              height: NotchConstants.panelHeight))
        panel = NotchPanel(contentRect: contentRect)

        // Drag enter callback — auto-expand when files are dragged to notch
        panel.onDragEntered = { [weak self] in
            guard let self else { return }
            self.state.isDragHovering = true
            self.state.expand()
        }

        // Embed SwiftUI content
        let rootView = NotchContainerView()
            .environment(state)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: NotchConstants.panelWidth, height: NotchConstants.panelHeight)
        panel.contentView = hostingView
    }

    func showWindow() {
        panel.orderFrontRegardless()
    }

    func hideWindow() {
        panel.orderOut(nil)
    }

    /// The rect of the panel in screen coordinates
    var panelFrame: CGRect {
        panel.frame
    }

    /// Update interactive state based on expansion
    func updateInteractivity() {
        panel.setInteractive(state.isExpanded || state.isDragHovering)
    }
}
