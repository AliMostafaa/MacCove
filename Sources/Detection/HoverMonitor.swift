import AppKit
import Combine

final class HoverMonitor {
    private let state: NotchState
    private weak var windowController: NotchWindowController?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var collapseWorkItem: DispatchWorkItem?
    private var isMouseInsideExpandedArea = false

    init(state: NotchState, windowController: NotchWindowController) {
        self.state = state
        self.windowController = windowController
    }

    func start() {
        // Global monitor for when app is NOT focused (most common case)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.handleMouseMoved()
        }

        // Local monitor for when the panel IS focused (e.g., interacting with expanded content)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        collapseWorkItem?.cancel()
    }

    private func handleMouseMoved() {
        let mouseLocation = NSEvent.mouseLocation
        let sensitivity = state.settings.hoverSensitivity

        if state.isExpanded {
            // When expanded: check if mouse is in the expanded panel area
            let expandedRect = expandedHoverRect(sensitivity: sensitivity)
            if expandedRect.contains(mouseLocation) {
                cancelCollapse()
                isMouseInsideExpandedArea = true
            } else if isMouseInsideExpandedArea {
                isMouseInsideExpandedArea = false
                scheduleCollapse()
            }
        } else {
            // When collapsed: check if mouse is in the notch activation zone
            let activationRect = notchActivationRect(sensitivity: sensitivity)
            if activationRect.contains(mouseLocation) {
                cancelCollapse()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.state.expand()
                    self.windowController?.updateInteractivity()
                    self.isMouseInsideExpandedArea = true
                }
            }
        }
    }

    private func scheduleCollapse() {
        // Don't auto-collapse when opened via keyboard shortcut
        guard !state.isKeyboardPinned else { return }
        collapseWorkItem?.cancel()
        let delay = state.settings.collapseDelay
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.state.collapse()
                self.state.isDragHovering = false
                self.windowController?.updateInteractivity()
            }
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    /// The activation zone for triggering expansion
    private func notchActivationRect(sensitivity: CGFloat) -> CGRect {
        let screen = state.screenWithNotch ?? NSScreen.main!
        let sf = screen.frame
        let cw = NotchConstants.collapsedWidth
        let ch = NotchConstants.collapsedHeight
        switch state.settings.notchPosition {
        case .topCenter:
            return state.notchRect.insetBy(dx: -sensitivity, dy: -sensitivity / 2)
        case .bottomLeft:
            return CGRect(x: sf.minX - sensitivity,
                          y: sf.minY,
                          width: cw + sensitivity * 2,
                          height: ch + sensitivity)
        case .bottomRight:
            return CGRect(x: sf.maxX - cw - sensitivity,
                          y: sf.minY,
                          width: cw + sensitivity * 2,
                          height: ch + sensitivity)
        }
    }

    /// The hover zone for the expanded panel (prevents premature collapse)
    private func expandedHoverRect(sensitivity: CGFloat) -> CGRect {
        guard let panel = windowController?.panel else { return .zero }
        let pf = panel.frame
        let ew = NotchConstants.expandedWidth + sensitivity * 2
        let eh = NotchConstants.expandedHeight + sensitivity
        switch state.settings.notchPosition {
        case .topCenter:
            return CGRect(x: pf.midX - ew / 2, y: pf.maxY - eh, width: ew, height: eh)
        case .bottomLeft:
            return CGRect(x: pf.minX - sensitivity, y: pf.minY, width: ew, height: eh)
        case .bottomRight:
            return CGRect(x: pf.maxX - NotchConstants.expandedWidth - sensitivity,
                          y: pf.minY, width: ew, height: eh)
        }
    }

    deinit {
        stop()
    }
}
