import AppKit

final class NotchPanel: NSPanel {

    var onDragEntered: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none

        // Start with mouse events ignored so menu bar clicks pass through
        ignoresMouseEvents = true

        // Register for drag types
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            .png,
            .tiff
        ])
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Mouse Event Control

    func setInteractive(_ interactive: Bool) {
        ignoresMouseEvents = !interactive
    }

    // MARK: - Drag & Drop (works even when ignoresMouseEvents = true)

    func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return .copy
    }

    func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        // Drag is handled by SwiftUI's DropDelegate in the ShelfView
        return false
    }
}
