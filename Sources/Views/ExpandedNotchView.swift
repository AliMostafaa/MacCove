import SwiftUI

struct ExpandedNotchView: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        ZStack(alignment: .top) {
            // Ambient background — artwork bloom behind everything
            pageBackground

            VStack(spacing: 0) {
                pageTabBar
                Group {
                    switch state.currentPage {
                    case .nowPlaying:
                        NowPlayingView()
                    case .shelf:
                        ShelfView()
                    case .clipboard:
                        ClipboardView()
                    case .widgets:
                        WidgetPageView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Ambient Background

    @ViewBuilder
    private var pageBackground: some View {
        if state.currentPage == .nowPlaying && state.nowPlaying.hasTrack {
            ZStack {
                // Base dark gradient — always shown for now playing
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.07, blue: 0.18),
                        Color(red: 0.05, green: 0.07, blue: 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Blurred artwork on top when loaded
                if let artwork = state.nowPlaying.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 55, opaque: true)
                        .overlay(Color.black.opacity(0.58))
                        .transition(.opacity.animation(.easeInOut(duration: 0.6)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.animation(.easeInOut(duration: 0.35)))
        }
    }

    // MARK: - Tab Bar

    private var pageTabBar: some View {
        HStack(spacing: 2) {
            ForEach(NotchPage.allCases) { page in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.currentPage = page
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: page.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(page.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(state.currentPage == page ? .white : .white.opacity(0.35))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        if state.currentPage == page {
                            Capsule()
                                .fill(.white.opacity(0.12))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}
