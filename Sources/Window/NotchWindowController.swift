import AppKit
import SwiftUI

final class NotchWindowController {
    private let state: NotchState
    private(set) var panel: NotchPanel!

    init(state: NotchState) {
        self.state = state
        setupPanel()
    }

    private func setupPanel() {
        let screen = state.screenWithNotch ?? NSScreen.main!
        let screenFrame = screen.frame

        // Position the panel centered at the top of the screen
        let panelWidth = NotchConstants.panelWidth
        let panelHeight = NotchConstants.panelHeight
        let panelX = screenFrame.midX - panelWidth / 2
        let panelY = screenFrame.maxY - panelHeight

        let contentRect = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)
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
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
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
