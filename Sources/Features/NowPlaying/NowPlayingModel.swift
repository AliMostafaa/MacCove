import AppKit

@Observable
final class NowPlayingModel {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var artwork: NSImage?
    var isPlaying: Bool = false
    var duration: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    var playbackRate: Double = 0

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsedTime / duration, 1.0)
    }

    var hasTrack: Bool {
        !title.isEmpty
    }

    var formattedElapsed: String {
        formatTime(elapsedTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
