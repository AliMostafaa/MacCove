import SwiftUI
import UniformTypeIdentifiers

struct NotchContainerView: View {
    @Environment(NotchState.self) private var state

    // Drives expanded content fade — decoupled so content appears
    // slightly after the shape, and vanishes slightly before.
    @State private var contentOpacity: Double = 0

    private var isDot: Bool { state.isMinimized && !state.isExpanded }
    private var position: NotchPosition { state.settings.notchPosition }

    private var stackAlignment: Alignment {
        switch position {
        case .topCenter:   return .top
        case .bottomLeft:  return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }

    private var expandedEdgePadding: Edge.Set {
        position.isCorner ? .bottom : .top
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: stackAlignment) {

                // ── Dot (minimized) ───────────────────────────────────────────
                RoundedRectangle(cornerRadius: NotchConstants.dotCornerRadius)
                    .fill(.black)
                    .frame(width: NotchConstants.dotSize, height: NotchConstants.dotSize)
                    .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                    .opacity(isDot ? 1 : 0)
                    .allowsHitTesting(false)

                // ── Shape ─────────────────────────────────────────────────────
                AdaptiveNotchShape(progress: state.isExpanded ? 1 : 0, position: position)
                    .fill(state.isExpanded
                          ? NotchConstants.expandedBackground
                          : NotchConstants.notchBackground)
                    .shadow(
                        color: .black.opacity(state.isExpanded ? 0.40 : 0.10),
                        radius: state.isExpanded ? 22 : 4,
                        x: 0, y: state.isExpanded ? (position.isCorner ? -10 : 10) : (position.isCorner ? -2 : 2)
                    )
                    .shadow(
                        color: .black.opacity(state.isExpanded ? 0.16 : 0.04),
                        radius: state.isExpanded ? 7 : 2,
                        x: 0, y: state.isExpanded ? (position.isCorner ? -3 : 3) : (position.isCorner ? -1 : 1)
                    )
                    .shadow(
                        color: NotchConstants.accentGlow.opacity(state.isExpanded ? 0.05 : 0.01),
                        radius: state.isExpanded ? 28 : 3,
                        x: 0, y: state.isExpanded ? (position.isCorner ? -14 : 14) : 0
                    )
                    .drawingGroup()
                    .opacity(isDot ? 0 : 1)
                    .allowsHitTesting(!isDot)

                // ── Content ───────────────────────────────────────────────────
                ZStack(alignment: stackAlignment) {
                    CollapsedNotchView()
                        .opacity(state.isExpanded ? 0 : 1)
                        .allowsHitTesting(!state.isExpanded)

                    ExpandedNotchView()
                        .frame(
                            width:  NotchConstants.expandedWidth  - 32,
                            height: NotchConstants.expandedHeight - 20
                        )
                        .padding(expandedEdgePadding, 12)
                        .opacity(contentOpacity)
                        .allowsHitTesting(state.isExpanded && contentOpacity > 0.5)
                }
                .clipShape(AdaptiveNotchShape(progress: state.isExpanded ? 1 : 0, position: position))
                .opacity(isDot ? 0 : 1)
                .allowsHitTesting(!isDot)
            }
            .animation(NotchConstants.spring, value: state.isExpanded)
            .animation(NotchConstants.spring, value: state.isMinimized)
            .animation(NotchConstants.spring, value: position)
            .frame(width: NotchConstants.panelWidth, height: NotchConstants.panelHeight, alignment: stackAlignment)
            .onChange(of: state.isExpanded) { _, expanded in
                // Notify services so they can pause/resume expensive work
                NotificationCenter.default.post(
                    name: .init("MacCove.notchExpansionChanged"),
                    object: nil,
                    userInfo: ["expanded": expanded]
                )

                if expanded {
                    withAnimation(.easeOut(duration: 0.22).delay(0.10)) {
                        contentOpacity = 1
                    }
                } else {
                    withAnimation(.easeIn(duration: 0.10)) {
                        contentOpacity = 0
                    }
                }
            }
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
        .frame(width: NotchConstants.panelWidth, height: NotchConstants.panelHeight, alignment: stackAlignment)
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
