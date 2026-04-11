import SwiftUI

struct CollapsedNotchView: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        HStack(spacing: 0) {
            // Left wing — now playing
            if state.nowPlaying.isPlaying || state.nowPlaying.hasTrack {
                leftWing
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            Spacer(minLength: 0)

            // Right wing — equalizer / shelf badge
            if state.nowPlaying.isPlaying || !state.shelf.items.isEmpty {
                rightWing
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.nowPlaying.isPlaying)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.shelf.items.count)
        .frame(width: NotchConstants.collapsedWidth, height: NotchConstants.collapsedHeight)
    }

    // MARK: - Left Wing

    private var leftWing: some View {
        HStack(spacing: 7) {
            // Album art thumbnail
            artworkThumbnail

            // Track title + playback indicator
            VStack(alignment: .leading, spacing: 1) {
                Text(state.nowPlaying.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .frame(maxWidth: 62, alignment: .leading)

                Text(state.nowPlaying.artist)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
                    .frame(maxWidth: 62, alignment: .leading)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
    }

    private var artworkThumbnail: some View {
        ZStack {
            if let artwork = state.nowPlaying.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.white.opacity(0.08))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.3))
                    )
            }

            // Pulsing ring when playing
            if state.nowPlaying.isPlaying {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(NotchConstants.accentGlow.opacity(0.5), lineWidth: 1)
                    .frame(width: 22, height: 22)
            }
        }
    }

    // MARK: - Right Wing

    private var rightWing: some View {
        HStack(spacing: 6) {
            if state.nowPlaying.isPlaying {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        MusicBar(index: index)
                    }
                }
                .frame(width: 14, height: 12)
            }

            if !state.shelf.items.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 7))
                    Text("\(state.shelf.items.count)")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.trailing, 10)
        .padding(.leading, 4)
    }
}

// MARK: - Music Equalizer Bars

private struct MusicBar: View {
    let index: Int
    @State private var height: CGFloat = 3

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(NotchConstants.accentGlow)
            .frame(width: 2, height: height)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.35 + Double(index) * 0.12)
                    .repeatForever(autoreverses: true)
                ) {
                    height = 8 + CGFloat(index) * 2
                }
            }
    }
}
