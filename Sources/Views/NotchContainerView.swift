import SwiftUI
import UniformTypeIdentifiers

struct NotchContainerView: View {
    @Environment(NotchState.self) private var state

    // Decouples content entrance from shape expansion:
    // shape grows first, THEN content fades in
    @State private var showExpandedContent = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {

                // ── Background shape — morphs between collapsed & expanded ──
                NotchShapeWithEars(progress: state.isExpanded ? 1 : 0)
                    .fill(state.isExpanded
                          ? NotchConstants.expandedBackground
                          : NotchConstants.notchBackground)
                    // Deep ambient shadow — always present, just much softer when collapsed
                    // Never goes to radius 0 so the animation interpolates smoothly (no pop)
                    .shadow(
                        color: .black.opacity(state.isExpanded ? 0.42 : 0.12),
                        radius: state.isExpanded ? 24 : 4,
                        x: 0, y: state.isExpanded ? 10 : 2
                    )
                    // Mid shadow — adds depth right at the bottom edge
                    .shadow(
                        color: .black.opacity(state.isExpanded ? 0.18 : 0.05),
                        radius: state.isExpanded ? 8 : 2,
                        x: 0, y: state.isExpanded ? 4 : 1
                    )
                    // Subtle accent bloom — very faint, just a hint of colour
                    .shadow(
                        color: NotchConstants.accentGlow.opacity(state.isExpanded ? 0.06 : 0),
                        radius: state.isExpanded ? 32 : 2,
                        x: 0, y: state.isExpanded ? 16 : 0
                    )
                    // Shape morph animates on the same spring as the content
                    .animation(
                        state.isExpanded ? NotchConstants.openSpring : NotchConstants.closeSpring,
                        value: state.isExpanded
                    )

                // ── Content — always clipped to the live notch shape ────────
                Group {
                    if state.isExpanded && showExpandedContent {
                        // Shape has already grown — now content blooms in
                        ExpandedNotchView()
                            .frame(
                                width:  NotchConstants.expandedWidth  - 32,
                                height: NotchConstants.expandedHeight - 20
                            )
                            .padding(.top, 12)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(
                                    with: .scale(scale: 0.97, anchor: .top)
                                ),
                                removal: .opacity
                            ))
                    } else if !state.isExpanded {
                        CollapsedNotchView()
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal:   .opacity
                            ))
                    }
                    // While isExpanded but !showExpandedContent: render nothing —
                    // shape is growing but content hasn't appeared yet
                }
                // Clip content to the animating notch shape — zero bleed
                .clipShape(NotchShapeWithEars(progress: state.isExpanded ? 1 : 0))
                .animation(
                    state.isExpanded ? NotchConstants.openSpring : NotchConstants.closeSpring,
                    value: state.isExpanded
                )
                .onChange(of: state.isExpanded) { _, expanded in
                    if expanded {
                        // Let the shape grow for ~160 ms, then fade content in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                showExpandedContent = true
                            }
                        }
                    } else {
                        // Content must vanish instantly so the shrinking shape clips cleanly
                        showExpandedContent = false
                    }
                }
            }
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
                    if let url  = item as? URL    { resolvedURL = url }
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
