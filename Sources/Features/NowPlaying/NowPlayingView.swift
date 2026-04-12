import SwiftUI

struct NowPlayingView: View {
    @Environment(NotchState.self) private var state
    @State private var isHoveringProgress = false
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0

    var body: some View {
        if state.nowPlaying.hasTrack {
            trackView
        } else {
            emptyView
        }
    }

    // MARK: - Track View

    private var trackView: some View {
        HStack(alignment: .center, spacing: 0) {
            artworkView
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                trackInfoView
                Spacer(minLength: 14)
                controlsView
                Spacer(minLength: 16)
                progressView
                Spacer(minLength: 10)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Artwork

    private var artworkView: some View {
        Group {
            if let artwork = state.nowPlaying.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 158, height: 158)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    // Layered shadow: deep ambient + mid contact for physical depth
                    .shadow(color: .black.opacity(0.70), radius: 28, x: 0, y: 14)
                    .shadow(color: .black.opacity(0.25), radius: 8,  x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.09), lineWidth: 0.5)
                    )
                    // Subtle lift/settle on play state change
                    .scaleEffect(state.nowPlaying.isPlaying ? 1.0 : 0.96)
                    .animation(
                        state.nowPlaying.isPlaying
                            ? .spring(response: 0.55, dampingFraction: 0.70)
                            : .spring(response: 0.40, dampingFraction: 0.88),
                        value: state.nowPlaying.isPlaying
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.15, blue: 0.35),
                                    Color(red: 0.10, green: 0.13, blue: 0.28),
                                    Color(red: 0.14, green: 0.09, blue: 0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .fill(.white.opacity(0.04))
                        .frame(width: 100, height: 100)
                        .offset(x: -28, y: -32)
                    Circle()
                        .fill(.white.opacity(0.025))
                        .frame(width: 70, height: 70)
                        .offset(x: 38, y: 28)
                    Image(systemName: "music.note")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.18))
                }
                .frame(width: 158, height: 158)
                .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 10)
            }
        }
    }

    // MARK: - Track Info

    private var trackInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.nowPlaying.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(state.nowPlaying.artist)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)

            if !state.nowPlaying.album.isEmpty {
                Text(state.nowPlaying.album)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.28))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Controls

    private var controlsView: some View {
        HStack(spacing: 16) {
            // Previous
            MediaButton(icon: "backward.fill", size: 18) {
                NotificationCenter.default.post(name: .init("MacCove.previousTrack"), object: nil)
            }

            // Play / Pause — primary action, larger and luminous
            Button {
                NotificationCenter.default.post(name: .init("MacCove.togglePlayPause"), object: nil)
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 52, height: 52)
                        .shadow(color: .white.opacity(0.18), radius: 14, x: 0, y: 4)
                        .shadow(color: .white.opacity(0.08), radius: 28, x: 0, y: 8)

                    Image(systemName: state.nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.black)
                        .offset(x: state.nowPlaying.isPlaying ? 0 : 2)
                        .animation(.spring(response: 0.22, dampingFraction: 0.80), value: state.nowPlaying.isPlaying)
                }
                .scaleEffect(1.0)
                .contentShape(Circle())
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.93))

            // Next
            MediaButton(icon: "forward.fill", size: 18) {
                NotificationCenter.default.post(name: .init("MacCove.nextTrack"), object: nil)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let barWidth = geo.size.width
                let displayProgress = isScrubbing ? scrubProgress : state.nowPlaying.progress
                let fillWidth = barWidth * displayProgress
                let isActive = isHoveringProgress || isScrubbing

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(.white.opacity(0.13))
                        .frame(height: isActive ? 5 : 3)
                        .animation(.easeOut(duration: 0.14), value: isActive)

                    // Fill
                    Capsule()
                        .fill(.white)
                        .frame(width: max(fillWidth, 0), height: isActive ? 5 : 3)
                        .animation(.easeOut(duration: 0.14), value: isActive)

                    // Scrub thumb — springs in on hover
                    if isActive {
                        Circle()
                            .fill(.white)
                            .frame(
                                width:  isScrubbing ? 14 : 11,
                                height: isScrubbing ? 14 : 11
                            )
                            .shadow(color: .black.opacity(0.25), radius: 3)
                            .position(
                                x: min(max(fillWidth, 6), barWidth - 6),
                                y: geo.size.height / 2
                            )
                            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isScrubbing)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isScrubbing = true
                            scrubProgress = min(max(value.location.x / barWidth, 0), 1)
                        }
                        .onEnded { value in
                            let fraction = min(max(value.location.x / barWidth, 0), 1)
                            let targetTime = fraction * state.nowPlaying.duration
                            NotificationCenter.default.post(
                                name: .init("MacCove.seekTo"),
                                object: nil,
                                userInfo: ["time": targetTime]
                            )
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 14)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isHoveringProgress = hovering
                }
            }

            HStack {
                Text(scrubTimeLabel)
                Spacer()
                Text(state.nowPlaying.formattedDuration)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var scrubTimeLabel: String {
        if isScrubbing {
            let time = scrubProgress * state.nowPlaying.duration
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        return state.nowPlaying.formattedElapsed
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.04))
                    .frame(width: 80, height: 80)
                Image(systemName: "waveform")
                    .font(.system(size: 32, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.13))
            }
            VStack(spacing: 4) {
                Text("Nothing Playing")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.22))
                Text("Play a track to see it here")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.11))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Reusable media button

private struct MediaButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(.white.opacity(isHovered ? 0.95 : 0.72))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(isHovered ? 0.10 : 0.065))
                )
                .scaleEffect(isHovered ? 1.04 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isHovered)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.90))
        .onHover { isHovered = $0 }
    }
}

// MARK: - Press scale button style

private struct PressScaleButtonStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
