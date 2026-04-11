import SwiftUI
import UniformTypeIdentifiers

struct NotchContainerView: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background shape
                NotchShapeWithEars(progress: state.isExpanded ? 1 : 0)
                    .fill(state.isExpanded ? NotchConstants.expandedBackground : NotchConstants.notchBackground)
                    .shadow(
                        color: state.isExpanded ? .black.opacity(0.5) : .clear,
                        radius: state.isExpanded ? 20 : 0,
                        y: state.isExpanded ? 10 : 0
                    )

                // Content
                if state.isExpanded {
                    ExpandedNotchView()
                        .frame(
                            width: NotchConstants.expandedWidth - 32,
                            height: NotchConstants.expandedHeight - 20
                        )
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                } else {
                    CollapsedNotchView()
                        .transition(.opacity)
                }

            }
            .frame(width: NotchConstants.panelWidth, height: NotchConstants.panelHeight, alignment: .top)
            .animation(
                .spring(response: NotchConstants.springResponse, dampingFraction: NotchConstants.springDamping),
                value: state.isExpanded
            )
            // Drop target
            .onDrop(of: [.fileURL, .url, .image], isTargeted: Binding(
                get: { state.isDragHovering },
                set: { newValue in
                    state.isDragHovering = newValue
                    if newValue {
                        state.expand()
                        state.currentPage = .shelf
                    }
                }
            )) { providers in
                handleDrop(providers)
                return true
            }
        }
        .frame(width: NotchConstants.panelWidth, height: NotchConstants.panelHeight, alignment: .top)
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            // Method 1: loadFileRepresentation — best for Finder file drops
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, error in
                    guard let url else { return }
                    // loadFileRepresentation gives a temp copy, get the original path from pasteboard
                    let originalURL = url
                    DispatchQueue.main.async {
                        state.shelf.addItem(from: originalURL)
                    }
                }
                continue
            }

            // Method 2: loadItem with various type casts
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    var resolvedURL: URL?
                    if let url = item as? URL {
                        resolvedURL = url
                    } else if let data = item as? Data {
                        resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let string = item as? String, let url = URL(string: string) {
                        resolvedURL = url
                    }
                    guard let url = resolvedURL else { return }
                    DispatchQueue.main.async {
                        state.shelf.addItem(from: url)
                    }
                }
            }
        }
    }
}
