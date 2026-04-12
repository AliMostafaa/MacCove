import SwiftUI
import UniformTypeIdentifiers

struct NotchContainerView: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {

                // ── Background shape ──────────────────────────────────────────
                // Three-layer shadow system: deep ambient → mid contact → accent glow.
                // The glow fades in with the expansion so the panel appears to emit
                // a soft light as it opens.
                NotchShapeWithEars(progress: state.isExpanded ? 1 : 0)
                    .fill(state.isExpanded
                          ? NotchConstants.expandedBackground
                          : NotchConstants.notchBackground)
                    // Deep ambient shadow — gives physical depth
                    .shadow(
                        color: .black.opacity(state.isExpanded ? 0.72 : 0),
                        radius: state.isExpanded ? 36 : 0,
                        x: 0, y: state.isExpanded ? 20 : 0
                    )
                    // Mid contact shadow — crisp edge definition
                    .shadow(
                        color: .black.opacity(state.isExpanded ? 0.30 : 0),
                        radius: state.isExpanded ? 10 : 0,
                        x: 0, y: state.isExpanded ? 4 : 0
                    )
                    // Accent glow — subtle color bloom matching the UI accent
                    .shadow(
                        color: NotchConstants.accentGlow.opacity(state.isExpanded ? 0.07 : 0),
                        radius: state.isExpanded ? 48 : 0,
                        x: 0, y: state.isExpanded ? 24 : 0
                    )

                // ── Content ───────────────────────────────────────────────────
                // Scale starts at 0.93 (not 0.85) so the entrance feels like a
                // gentle reveal rather than a dramatic pop.
                if state.isExpanded {
                    ExpandedNotchView()
                        .frame(
                            width: NotchConstants.expandedWidth - 32,
                            height: NotchConstants.expandedHeight - 20
                        )
                        .padding(.top, 12)
                        .transition(
                            .opacity
                            .combined(with: .scale(scale: 0.93, anchor: .top))
                        )
                        .animation(NotchConstants.contentEntrance, value: state.isExpanded)
                } else {
                    CollapsedNotchView()
                        .transition(.opacity)
                        .animation(NotchConstants.closeSpring, value: state.isExpanded)
                }
            }
            .frame(width: NotchConstants.panelWidth, height: NotchConstants.panelHeight, alignment: .top)
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
