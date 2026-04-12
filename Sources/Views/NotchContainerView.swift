import SwiftUI
import UniformTypeIdentifiers

struct NotchContainerView: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {

                NotchShapeWithEars(progress: state.isExpanded ? 1 : 0)
                    .fill(state.isExpanded
                          ? NotchConstants.expandedBackground
                          : NotchConstants.notchBackground)
                    .shadow(
                        color: .black.opacity(state.isExpanded ? 0.72 : 0),
                        radius: state.isExpanded ? 36 : 0,
                        x: 0, y: state.isExpanded ? 20 : 0
                    )
                    .shadow(
                        color: .black.opacity(state.isExpanded ? 0.30 : 0),
                        radius: state.isExpanded ? 10 : 0,
                        x: 0, y: state.isExpanded ? 4 : 0
                    )
                    .shadow(
                        color: NotchConstants.accentGlow.opacity(state.isExpanded ? 0.07 : 0),
                        radius: state.isExpanded ? 48 : 0,
                        x: 0, y: state.isExpanded ? 24 : 0
                    )

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
            // File from Finder — loadItem gives the original URL (not a temp copy)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { state.shelf.addItem(from: url) }
                }
                continue
            }

            // Web URL dropped from browser
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    var resolvedURL: URL?
                    if let url = item as? URL { resolvedURL = url }
                    else if let data = item as? Data { resolvedURL = URL(dataRepresentation: data, relativeTo: nil) }
                    else if let string = item as? String, let url = URL(string: string) { resolvedURL = url }
                    guard let url = resolvedURL else { return }
                    DispatchQueue.main.async { state.shelf.addItem(from: url) }
                }
                continue
            }

            // Image dragged directly (browser, Photos, Preview, etc.)
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadObject(ofClass: NSImage.self) { object, _ in
                    guard let image = object as? NSImage else { return }
                    DispatchQueue.main.async { state.shelf.addImageItem(image) }
                }
            }
        }
    }
}
