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

    /// Timestamp when elapsedTime was last set — allows computing
    /// live progress without a tick timer (collapsed notch uses this).
    var elapsedTimeSetAt: Date = Date()

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsedTime / duration, 1.0)
    }

    /// Estimated progress accounting for time since last update.
    /// Used by collapsed notch to show a live-ish progress bar
    /// without running a tick timer.
    var estimatedProgress: Double {
        guard duration > 0 else { return 0 }
        var elapsed = elapsedTime
        if isPlaying {
            elapsed += Date().timeIntervalSince(elapsedTimeSetAt)
        }
        return min(elapsed / duration, 1.0)
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
