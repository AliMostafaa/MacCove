import SwiftUI
import UniformTypeIdentifiers

struct NotchContainerView: View {
    @Environment(NotchState.self) private var state

    // Content opacity is decoupled so it fades slightly behind the shape morph.
    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {

                // ── Shape ─────────────────────────────────────────────────────
                // One shape, one spring. This IS the animation.
                NotchShapeWithEars(progress: state.isExpanded ? 1 : 0)
                    .fill(state.isExpanded
                          ? NotchConstants.expandedBackground
                          : NotchConstants.notchBackground)
                    .shadow(
                        color: .black.opacity(state.isExpanded ? 0.40 : 0.10),
                        radius: state.isExpanded ? 22 : 4,
                        x: 0, y: state.isExpanded ? 10 : 2
                    )
                    .shadow(
                        color: .black.opacity(state.isExpanded ? 0.16 : 0.04),
                        radius: state.isExpanded ? 7 : 2,
                        x: 0, y: state.isExpanded ? 3 : 1
                    )
                    .shadow(
                        color: NotchConstants.accentGlow.opacity(state.isExpanded ? 0.05 : 0.01),
                        radius: state.isExpanded ? 28 : 3,
                        x: 0, y: state.isExpanded ? 14 : 0
                    )

                // ── Content ───────────────────────────────────────────────────
                // Both views always exist — no if/else branching, no view
                // identity changes, no competing transitions. The shape
                // reveals them through the clip; opacity does the rest.
                ZStack(alignment: .top) {
                    // Collapsed
                    CollapsedNotchView()
                        .opacity(state.isExpanded ? 0 : 1)

                    // Expanded
                    ExpandedNotchView()
                        .frame(
                            width:  NotchConstants.expandedWidth  - 32,
                            height: NotchConstants.expandedHeight - 20
                        )
                        .padding(.top, 12)
                        .opacity(contentOpacity)
                }
                .clipShape(NotchShapeWithEars(progress: state.isExpanded ? 1 : 0))
                .drawingGroup(opaque: false)
            }
            // Single animation drives EVERYTHING — shape, clip, shadows, opacity
            .animation(NotchConstants.spring, value: state.isExpanded)
            .frame(width: NotchConstants.panelWidth, height: NotchConstants.panelHeight, alignment: .top)
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
            .onChange(of: state.isExpanded) { _, expanded in
                if expanded {
                    // Fade content in slightly after the shape starts growing
                    withAnimation(.easeOut(duration: 0.25).delay(0.12)) {
                        contentOpacity = 1
                    }
                } else {
                    // Fade content out quickly, shape shrinks around it
                    withAnimation(.easeIn(duration: 0.12)) {
                        contentOpacity = 0
                    }
                }
            }
        }
        .frame(width: NotchConstants.panelWidth, height: NotchConstants.panelHeight, alignment: .top)
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { state.shelf.addItem(from: url) }
                }
                continue
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    var resolvedURL: URL?
                    if let url    = item as? URL    { resolvedURL = url }
                    else if let data   = item as? Data   { resolvedURL = URL(dataRepresentation: data, relativeTo: nil) }
                    else if let string = item as? String, let url = URL(string: string) { resolvedURL = url }
                    guard let url = resolvedURL else { return }
                    DispatchQueue.main.async { state.shelf.addItem(from: url) }
                }
                continue
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadObject(ofClass: NSImage.self) { object, _ in
                    guard let image = object as? NSImage else { return }
                    DispatchQueue.main.async { state.shelf.addImageItem(image) }
                }
            }
        }
    }
}
