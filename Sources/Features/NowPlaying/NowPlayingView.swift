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
            // Left: Album artwork
            artworkView
                .padding(.leading, 16)

            // Right: Track info, controls, progress
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
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.65), radius: 22, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.15, blue: 0.35),
                                    Color(red: 0.1, green: 0.13, blue: 0.28),
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
                        .foregroundStyle(.white.opacity(0.2))
                }
                .frame(width: 158, height: 158)
                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
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
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)

            if !state.nowPlaying.album.isEmpty {
                Text(state.nowPlaying.album)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Controls

    private var controlsView: some View {
        HStack(spacing: 18) {
            // Previous
            Button {
                NotificationCenter.default.post(name: .init("MacCove.previousTrack"), object: nil)
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // Play / Pause
            Button {
                NotificationCenter.default.post(name: .init("MacCove.togglePlayPause"), object: nil)
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 52, height: 52)
                        .shadow(color: .white.opacity(0.2), radius: 12)

                    Image(systemName: state.nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.black)
                        .offset(x: state.nowPlaying.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)

            // Next
            Button {
                NotificationCenter.default.post(name: .init("MacCove.nextTrack"), object: nil)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
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

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.14))
                        .frame(height: (isHoveringProgress || isScrubbing) ? 5 : 3)

                    Capsule()
                        .fill(.white)
                        .frame(width: max(fillWidth, 0), height: (isHoveringProgress || isScrubbing) ? 5 : 3)

                    if isHoveringProgress || isScrubbing {
                        Circle()
                            .fill(.white)
                            .frame(width: isScrubbing ? 14 : 12, height: isScrubbing ? 14 : 12)
                            .shadow(color: .black.opacity(0.3), radius: 3)
                            .position(x: min(max(fillWidth, 6), barWidth - 6), y: geo.size.height / 2)
                            .transition(.scale)
                    }
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = min(max(value.location.x / barWidth, 0), 1)
                            isScrubbing = true
                            scrubProgress = fraction
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
                withAnimation(.easeOut(duration: 0.15)) {
                    isHoveringProgress = hovering
                }
            }

            HStack {
                Text(scrubTimeLabel)
                Spacer()
                Text(state.nowPlaying.formattedDuration)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.38))
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
                    .foregroundStyle(.white.opacity(0.15))
            }
            VStack(spacing: 4) {
                Text("Nothing Playing")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
                Text("Play a track to see it here")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
