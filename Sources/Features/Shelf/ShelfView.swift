import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Drop Zone")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                if !state.shelf.items.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state.shelf.clearAll()
                        }
                    } label: {
                        Text("Clear All")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

            if state.shelf.items.isEmpty {
                emptyState
            } else {
                itemsGrid
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .foregroundStyle(.white.opacity(0.1))

                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Drop files or links here")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                    Text("Stored temporarily for quick access")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.15))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
        }
    }

    private var itemsGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(state.shelf.items) { item in
                    ShelfItemCard(item: item)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, 4)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.shelf.items.count)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Card

private struct ShelfItemCard: View {
    @Environment(NotchState.self) private var state
    let item: ShelfItem
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                thumbnailView
                    .frame(width: 110, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if isHovered {
                    Button {
                        withAnimation { state.shelf.removeItem(item) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white, .red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            // Info label
            if item.isWebLink {
                linkInfoLabel
            } else {
                fileInfoLabel
            }
        }
        .padding(6)
        .frame(width: 122)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(isHovered ? 0.08 : 0.04)))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .onTapGesture {
            state.shelf.openItem(item)
        }
        .contextMenu {
            // ── Open ──────────────────────────────────────────────────────────
            Button {
                state.shelf.openItem(item)
            } label: {
                Label(item.isWebLink ? "Open in Browser" : "Open", systemImage: item.isWebLink ? "safari" : "arrow.up.right.square")
            }

            // ── Copy Image ────────────────────────────────────────────────────
            if item.isImage, let image = NSImage(contentsOf: item.url) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([image])
                } label: {
                    Label("Copy Image", systemImage: "doc.on.doc")
                }
            }

            // ── Finder / Copy URL ─────────────────────────────────────────────
            if item.isWebLink {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.url.absoluteString, forType: .string)
                } label: {
                    Label("Copy URL", systemImage: "link")
                }
            } else {
                Button {
                    state.shelf.revealItem(item)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.url.path, forType: .string)
                } label: {
                    Label("Copy File Path", systemImage: "doc.on.clipboard")
                }
            }

            Divider()

            // ── Share ─────────────────────────────────────────────────────────
            Button {
                let picker = NSSharingServicePicker(items: [item.url])
                if let view = NSApp.keyWindow?.contentView {
                    picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
                }
            } label: {
                Label("Share…", systemImage: "square.and.arrow.up")
            }

            Divider()

            // ── Remove ────────────────────────────────────────────────────────
            Button(role: .destructive) {
                withAnimation { state.shelf.removeItem(item) }
            } label: {
                Label("Remove from Shelf", systemImage: "trash")
            }
        }
        .draggable(item.url) {
            HStack(spacing: 8) {
                if let thumbnail = item.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text(item.displayName)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Info labels

    private var linkInfoLabel: some View {
        VStack(spacing: 2) {
            Text(item.linkTitle ?? item.linkDomain ?? "Link")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
            if let domain = item.linkDomain {
                Text(domain)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
            }
        }
        .frame(width: 110)
    }

    private var fileInfoLabel: some View {
        VStack(spacing: 3) {
            Text(item.fileName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .frame(width: 110)

            HStack(spacing: 4) {
                if let ext = item.fileExtensionLabel {
                    Text(ext)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.white.opacity(0.10)))
                }
                if let size = item.fileSize {
                    Text(size)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail = item.thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: item.isWebLink ? .fit : .fill)
                .background(Color.white.opacity(0.04))
        } else {
            ZStack {
                Color.white.opacity(0.06)
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
            }
        }
    }
}
