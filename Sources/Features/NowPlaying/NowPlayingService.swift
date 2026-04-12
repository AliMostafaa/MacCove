import AppKit

/// Bridges to the private MediaRemote.framework to get Now Playing info,
/// with fallback to distributed notifications for Spotify/Apple Music.
final class NowPlayingService {
    private let model: NowPlayingModel
    private var handle: UnsafeMutableRawPointer?
    private var timer: Timer?
    private var artworkRetryTimer: Timer?

    // Track whether distributed notification recently set isPlaying
    // so we don't let MediaRemote override it
    private var lastDistributedUpdate: Date = .distantPast

    // When false, tick() won't mutate elapsedTime — prevents @Observable
    // cascade to invisible DashboardView while collapsed.
    private(set) var isExpanded: Bool = false

    // Function type aliases for MediaRemote C functions
    private typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRMediaRemoteRegisterNotificationsFunction = @convention(c) (DispatchQueue) -> Void
    private typealias MRMediaRemoteSendCommandFunction = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool
    private typealias MRMediaRemoteSetElapsedTimeFunction = @convention(c) (Double) -> Void

    // Loaded functions
    private var getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction?
    private var registerNotifications: MRMediaRemoteRegisterNotificationsFunction?
    private var sendCommand: MRMediaRemoteSendCommandFunction?
    private var setElapsedTime: MRMediaRemoteSetElapsedTimeFunction?

    // MediaRemote command constants
    private static let kMRTogglePlayPause: UInt32 = 2
    private static let kMRNextTrack: UInt32 = 4
    private static let kMRPreviousTrack: UInt32 = 5

    init(model: NowPlayingModel) {
        self.model = model
        loadFramework()
    }

    private func loadFramework() {
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)
        guard let handle else { return }

        if let ptr = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfo = unsafeBitCast(ptr, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        }
        if let ptr = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            registerNotifications = unsafeBitCast(ptr, to: MRMediaRemoteRegisterNotificationsFunction.self)
        }
        if let ptr = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(ptr, to: MRMediaRemoteSendCommandFunction.self)
        }
        if let ptr = dlsym(handle, "MRMediaRemoteSetElapsedTime") {
            setElapsedTime = unsafeBitCast(ptr, to: MRMediaRemoteSetElapsedTimeFunction.self)
        }
    }

    func start() {
        registerNotifications?(DispatchQueue.main)

        // MediaRemote notifications
        let dnc = NotificationCenter.default
        dnc.addObserver(self, selector: #selector(mediaRemoteInfoChanged),
                        name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil)
        dnc.addObserver(self, selector: #selector(mediaRemoteInfoChanged),
                        name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"), object: nil)

        // Distributed notifications (Spotify, Apple Music) — these are the most reliable
        let ddc = DistributedNotificationCenter.default()
        ddc.addObserver(self, selector: #selector(spotifyNotification(_:)),
                        name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil)
        ddc.addObserver(self, selector: #selector(appleMusicNotification(_:)),
                        name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil)

        // Listen for notch expansion changes to pause/resume tick
        NotificationCenter.default.addObserver(
            forName: .init("MacCove.notchExpansionChanged"), object: nil, queue: .main
        ) { [weak self] notif in
            self?.isExpanded = notif.userInfo?["expanded"] as? Bool ?? false
        }

        // Initial fetch
        fetchFullInfo()

        // Periodic elapsed time tick
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        artworkRetryTimer?.invalidate()
        timer = nil
        artworkRetryTimer = nil
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        if let handle { dlclose(handle) }
    }

    // MARK: - MediaRemote Notification

    @objc private func mediaRemoteInfoChanged() {
        fetchFullInfo()
    }

    // MARK: - Spotify

    @objc private func spotifyNotification(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastDistributedUpdate = Date()

            self.model.title = info["Name"] as? String ?? self.model.title
            self.model.artist = info["Artist"] as? String ?? self.model.artist
            self.model.album = info["Album"] as? String ?? self.model.album

            if let durationMs = info["Duration"] as? Double, durationMs > 0 {
                self.model.duration = durationMs / 1000.0
            }
            if let position = info["Playback Position"] as? Double {
                self.model.elapsedTime = position
                self.model.elapsedTimeSetAt = Date()
            }

            let playerState = info["Player State"] as? String ?? ""
            self.model.isPlaying = (playerState == "Playing")
            self.model.playbackRate = self.model.isPlaying ? 1.0 : 0.0

            // Fetch artwork from MediaRemote (Spotify notifications don't include it)
            self.scheduleArtworkRetry()
        }
    }

    // MARK: - Apple Music

    @objc private func appleMusicNotification(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastDistributedUpdate = Date()

            self.model.title = info["Name"] as? String ?? self.model.title
            self.model.artist = info["Artist"] as? String ?? self.model.artist
            self.model.album = info["Album"] as? String ?? self.model.album

            if let totalTime = info["Total Time"] as? Double, totalTime > 0 {
                self.model.duration = totalTime / 1000.0  // Apple Music sends ms
            }

            let playerState = info["Player State"] as? String ?? ""
            self.model.isPlaying = (playerState == "Playing")
            self.model.playbackRate = self.model.isPlaying ? 1.0 : 0.0

            self.scheduleArtworkRetry()
        }
    }

    // MARK: - MediaRemote Full Fetch

    private func fetchFullInfo() {
        getNowPlayingInfo?(DispatchQueue.main) { [weak self] info in
            guard let self, !info.isEmpty else { return }

            let title = self.extract(info, "kMRMediaRemoteNowPlayingInfoTitle", "Title") as? String
            let artist = self.extract(info, "kMRMediaRemoteNowPlayingInfoArtist", "Artist") as? String
            let album = self.extract(info, "kMRMediaRemoteNowPlayingInfoAlbum", "Album") as? String
            let duration = self.extract(info, "kMRMediaRemoteNowPlayingInfoDuration", "Duration") as? TimeInterval
            let elapsed = self.extract(info, "kMRMediaRemoteNowPlayingInfoElapsedTime", "ElapsedTime") as? TimeInterval
            let rate = self.extract(info, "kMRMediaRemoteNowPlayingInfoPlaybackRate", "PlaybackRate") as? Double
            let artworkData = self.extract(info, "kMRMediaRemoteNowPlayingInfoArtworkData", "ArtworkData") as? Data

            if let title, !title.isEmpty { self.model.title = title }
            if let artist { self.model.artist = artist }
            if let album { self.model.album = album }
            if let duration, duration > 0 { self.model.duration = duration }
            if let elapsed {
                self.model.elapsedTime = elapsed
                self.model.elapsedTimeSetAt = Date()
            }

            // Derive isPlaying from playbackRate (more reliable than getIsPlaying)
            // But don't override if a distributed notification set it recently
            let recentlyUpdatedByDistributed = Date().timeIntervalSince(self.lastDistributedUpdate) < 3.0
            if !recentlyUpdatedByDistributed {
                if let rate {
                    self.model.playbackRate = rate
                    self.model.isPlaying = rate > 0
                }
            }

            if let artworkData, let image = NSImage(data: artworkData) {
                self.model.artwork = image
            }
        }
    }

    // MARK: - Artwork Retry

    private func scheduleArtworkRetry() {
        artworkRetryTimer?.invalidate()
        // First immediate attempt
        fetchArtworkOnly()

        var retries = 0
        artworkRetryTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            retries += 1
            self.fetchArtworkOnly()
            if self.model.artwork != nil || retries >= 5 {
                timer.invalidate()
            }
        }
    }

    private func fetchArtworkOnly() {
        getNowPlayingInfo?(DispatchQueue.main) { [weak self] info in
            guard let self, !info.isEmpty, self.model.artwork == nil else { return }
            if let data = self.extract(info, "kMRMediaRemoteNowPlayingInfoArtworkData", "ArtworkData") as? Data,
               let image = NSImage(data: data) {
                self.model.artwork = image
            }
        }
    }

    // MARK: - Timer Tick

    private func tick() {
        // Only mutate elapsedTime when expanded — the seek bar is the only
        // consumer. Collapsed notch never reads elapsedTime/progress, so
        // ticking while collapsed just triggers wasted @Observable cascades.
        guard model.isPlaying, model.duration > 0, isExpanded else { return }
        model.elapsedTime += 1.0
        model.elapsedTimeSetAt = Date()
        if model.elapsedTime > model.duration {
            model.elapsedTime = model.duration
        }
    }

    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
    }

    // MARK: - Helpers

    private func extract(_ dict: [String: Any], _ keys: String...) -> Any? {
        for key in keys { if let v = dict[key] { return v } }
        return nil
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        _ = sendCommand?(Self.kMRTogglePlayPause, nil)
        model.isPlaying.toggle()
        model.playbackRate = model.isPlaying ? 1.0 : 0.0
        model.elapsedTimeSetAt = Date()
        lastDistributedUpdate = Date() // protect from MediaRemote overriding
    }

    func nextTrack() {
        _ = sendCommand?(Self.kMRNextTrack, nil)
        model.elapsedTime = 0
        model.elapsedTimeSetAt = Date()
        model.artwork = nil
        scheduleArtworkRetry()
    }

    func previousTrack() {
        _ = sendCommand?(Self.kMRPreviousTrack, nil)
        model.elapsedTime = 0
        model.elapsedTimeSetAt = Date()
        model.artwork = nil
        scheduleArtworkRetry()
    }

    func seekTo(time: TimeInterval) {
        let clampedTime = min(max(time, 0), model.duration)
        model.elapsedTime = clampedTime
        model.elapsedTimeSetAt = Date()
        setElapsedTime?(clampedTime)
        lastDistributedUpdate = Date() // protect from MediaRemote overriding
    }

    deinit { stop() }
}
