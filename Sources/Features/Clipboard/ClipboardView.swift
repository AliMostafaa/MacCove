import SwiftUI

struct ClipboardView: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            if state.isClipboardSearchActive {
                searchBar
            }

            if displayedItems.isEmpty {
                if state.isClipboardSearchActive {
                    searchEmptyState
                } else {
                    emptyState
                }
            } else {
                if !state.isClipboardSearchActive {
                    header
                }
                itemList
                if !state.isClipboardSearchActive {
                    keyboardHint
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: state.clipboardSearchQuery) { _, _ in
            state.selectedClipboardIndex = 0
        }
        .onChange(of: state.clipboard.items.count) { _, count in
            state.selectedClipboardIndex = min(state.selectedClipboardIndex, max(count - 1, 0))
        }
    }

    private var displayedItems: [ClipboardItem] { state.filteredClipboardItems }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))

            Text(state.clipboardSearchQuery.isEmpty ? "Type to filter…" : state.clipboardSearchQuery)
                .font(.system(size: 12))
                .foregroundStyle(state.clipboardSearchQuery.isEmpty ? .white.opacity(0.25) : .white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(nil, value: state.clipboardSearchQuery)

            if !state.clipboardSearchQuery.isEmpty {
                Button { state.clipboardSearchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.30))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.07)))
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .transition(.opacity.combined(with: .offset(y: -4)))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("\(state.clipboard.items.count) item\(state.clipboard.items.count == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
            Button("Clear all") {
                withAnimation(.spring(response: 0.3)) {
                    state.clipboard.clear()
                    state.selectedClipboardIndex = 0
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.35))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    // MARK: - List

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 5) {
                    ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            isSelected: index == state.selectedClipboardIndex
                        ) {
                            state.clipboard.copy(item)
                            state.selectedClipboardIndex = index
                        } onDelete: {
                            withAnimation(.spring(response: 0.3)) {
                                state.clipboard.remove(item)
                            }
                        }
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .onChange(of: state.selectedClipboardIndex) { _, newIndex in
                guard newIndex < displayedItems.count else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(displayedItems[newIndex].id, anchor: .center)
                }
            }
        }
    }

    // MARK: - Keyboard Hint

    private var keyboardHint: some View {
        HStack(spacing: 10) {
            hintKey("↑↓", label: "navigate")
            hintKey("↵", label: "copy & close")
            hintKey("esc", label: "close")
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
    }

    private func hintKey(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.2))
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.04))
                    .frame(width: 64, height: 64)
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 24, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.18))
            }
            VStack(spacing: 4) {
                Text("No Clipboard History")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
                Text("Copy text or images to start tracking")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.14))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.15))
            Text("No results")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.22))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isSelected ? NotchConstants.accentGlow : .clear)
                .frame(width: 3, height: item.isImage ? 44 : 28)
                .animation(.easeInOut(duration: 0.15), value: isSelected)

            if let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Image")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
                    Text(item.preview)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.30))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(item.preview)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.timeLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))

                if isHovering || isSelected {
                    HStack(spacing: 6) {
                        Button {
                            onCopy()
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation { copied = false }
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(copied ? .green : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)

                        Button { onDelete() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
            }
            .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected
                    ? NotchConstants.accentGlow.opacity(0.12)
                    : (isHovering ? .white.opacity(0.06) : .white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected ? NotchConstants.accentGlow.opacity(0.3) : .clear,
                            lineWidth: 0.5
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { onCopy() }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
