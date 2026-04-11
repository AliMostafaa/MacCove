import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        VStack(spacing: 12) {
            // Header
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

                    Text("Drop files here")
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

// MARK: - Shelf Item Card

private struct ShelfItemCard: View {
    @Environment(NotchState.self) private var state
    let item: ShelfItem
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                thumbnailView
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                // Remove button (appears on hover)
                if isHovered {
                    Button {
                        withAnimation {
                            state.shelf.removeItem(item)
                        }
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

            Text(item.fileName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 90)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(isHovered ? 0.08 : 0.04))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            state.shelf.openItem(item)
        }
        .onTapGesture(count: 1) {
            state.shelf.revealItem(item)
        }
        .draggable(item.url) {
            // Drag preview
            HStack(spacing: 8) {
                if let thumbnail = item.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text(item.fileName)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail = item.thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
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
