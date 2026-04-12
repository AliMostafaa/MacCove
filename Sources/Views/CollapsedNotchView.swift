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
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: state.nowPlaying.isPlaying)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: state.shelf.items.count)
        .frame(width: NotchConstants.collapsedWidth, height: NotchConstants.collapsedHeight)
    }

    // MARK: - Left Wing

    private var leftWing: some View {
        HStack(spacing: 8) {
            artworkThumbnail
            trackLabels
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
    }

    private var artworkThumbnail: some View {
        ZStack {
            if let artwork = state.nowPlaying.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .scaleEffect(state.nowPlaying.isPlaying ? 1.0 : 0.92)
                    .animation(
                        state.nowPlaying.isPlaying
                            ? .spring(response: 0.5, dampingFraction: 0.72)
                            : .spring(response: 0.35, dampingFraction: 0.88),
                        value: state.nowPlaying.isPlaying
                    )
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.06))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.25))
                    )
            }

            // Subtle accent ring when playing
            if state.nowPlaying.isPlaying {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                NotchConstants.accentGlow.opacity(0.6),
                                NotchConstants.accentGlow.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 24, height: 24)
            }
        }
    }

    private var trackLabels: some View {
        VStack(alignment: .leading, spacing: 1.5) {
            Text(state.nowPlaying.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .frame(maxWidth: 80, alignment: .leading)

            Text(state.nowPlaying.artist)
                .font(.system(size: 8.5, weight: .regular))
                .foregroundStyle(.white.opacity(0.40))
                .lineLimit(1)
                .frame(maxWidth: 80, alignment: .leading)
        }
    }

    // MARK: - Right Wing

    private var rightWing: some View {
        HStack(spacing: 7) {
            if state.nowPlaying.isPlaying && !state.isExpanded {
                MusicEqualizer()
            }

            if !state.shelf.items.isEmpty {
                shelfBadge
            }
        }
        .padding(.trailing, 10)
        .padding(.leading, 4)
    }

    private var shelfBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "tray.fill")
                .font(.system(size: 7.5, weight: .medium))
            Text("\(state.shelf.items.count)")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.40))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(.white.opacity(0.06))
        )
    }
}

// MARK: - Music Equalizer Bars

/// Low-CPU equalizer: a slow timer (every 2s) picks new random target
/// heights, and SwiftUI's `.animation` smoothly interpolates between them.
/// SwiftUI only re-evaluates the body once per 2s — Core Animation handles
/// the smooth interpolation at the layer level with near-zero CPU.
private struct MusicEqualizer: View {
    @State private var heights: [CGFloat] = [5, 3, 7, 4]
    @State private var timer: Timer?

    // 3 bars looks cleaner in the tight collapsed space
    private static let barCount = 3
    private static let minH: [CGFloat] = [3, 4, 3]
    private static let maxH: [CGFloat] = [12, 9, 13]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<Self.barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                NotchConstants.accentGlow,
                                NotchConstants.accentGlow.opacity(0.45)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: heights[i])
            }
        }
        .frame(width: 16, height: 14, alignment: .bottom)
        .drawingGroup()
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private func startTimer() {
        randomise()
        // 2.0s interval with 0.18s animation = ~9% duty cycle
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            randomise()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func randomise() {
        withAnimation(.easeInOut(duration: 0.18)) {
            for i in 0..<Self.barCount {
                heights[i] = CGFloat.random(in: Self.minH[i]...Self.maxH[i])
            }
        }
    }
}
