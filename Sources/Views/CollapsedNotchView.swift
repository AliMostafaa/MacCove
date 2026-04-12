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
        HStack(spacing: 7) {
            artworkThumbnail
            trackLabels
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
                    // Subtle scale-breathe when playing
                    .scaleEffect(state.nowPlaying.isPlaying ? 1.0 : 0.92)
                    .animation(
                        state.nowPlaying.isPlaying
                            ? .spring(response: 0.5, dampingFraction: 0.72)
                            : .spring(response: 0.35, dampingFraction: 0.88),
                        value: state.nowPlaying.isPlaying
                    )
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

            // Pulsing accent ring when playing
            if state.nowPlaying.isPlaying {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(NotchConstants.accentGlow.opacity(0.55), lineWidth: 1)
                    .frame(width: 22, height: 22)
            }
        }
    }

    private var trackLabels: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(state.nowPlaying.title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .frame(maxWidth: 62, alignment: .leading)

            Text(state.nowPlaying.artist)
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
                .frame(maxWidth: 62, alignment: .leading)
        }
    }

    // MARK: - Right Wing

    private var rightWing: some View {
        HStack(spacing: 6) {
            if state.nowPlaying.isPlaying && !state.isExpanded {
                MusicEqualizer()
            }

            if !state.shelf.items.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 7))
                    Text("\(state.shelf.items.count)")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.trailing, 10)
        .padding(.leading, 4)
    }
}

// MARK: - Music Equalizer Bars

/// Low-CPU equalizer: a slow timer (every 0.8s) picks new random target
/// heights, and SwiftUI's `.animation` smoothly interpolates between them.
/// SwiftUI only re-evaluates the body once per 0.8s — Core Animation handles
/// the smooth interpolation at the layer level with near-zero CPU.
private struct MusicEqualizer: View {
    @State private var heights: [CGFloat] = [5, 3, 7, 4]
    @State private var timer: Timer?

    private static let minH: [CGFloat] = [2, 3, 2, 4]
    private static let maxH: [CGFloat] = [11, 7, 13, 9]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                NotchConstants.accentGlow,
                                NotchConstants.accentGlow.opacity(0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2.5, height: heights[i])
            }
        }
        .frame(width: 18, height: 14, alignment: .bottom)
        .drawingGroup()
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private func startTimer() {
        randomise()
        // 1.5s interval with 0.35s animation = ~23% duty cycle
        // CPU is zero during the ~1.15s idle gap between animations
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            randomise()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func randomise() {
        withAnimation(.easeInOut(duration: 0.18)) {
            for i in 0..<4 {
                heights[i] = CGFloat.random(in: Self.minH[i]...Self.maxH[i])
            }
        }
    }
}
