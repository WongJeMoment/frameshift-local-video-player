import AVFoundation
import Foundation

@MainActor
final class PlayerStore: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var fileName: String?
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isPlaying = false
    @Published var playbackRate: Double = 1
    @Published var volume: Double = 1 {
        didSet { player.volume = Float(volume) }
    }
    @Published var isMuted = false {
        didSet { player.isMuted = isMuted }
    }
    @Published var errorMessage: String?

    private var scopedURL: URL?
    private var hasSecurityScope = false
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    var hasVideo: Bool { fileName != nil }

    init() {
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let current = time.seconds
                let total = self.player.currentItem?.duration.seconds ?? 0
                self.currentTime = current.isFinite ? max(0, current) : 0
                self.duration = total.isFinite ? max(0, total) : 0
                if let error = self.player.currentItem?.error {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.isPlaying = false }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if hasSecurityScope { scopedURL?.stopAccessingSecurityScopedResource() }
    }

    func open(_ url: URL) {
        player.pause()
        if hasSecurityScope { scopedURL?.stopAccessingSecurityScopedResource() }

        hasSecurityScope = url.startAccessingSecurityScopedResource()
        scopedURL = url
        errorMessage = nil
        fileName = url.lastPathComponent
        currentTime = 0
        duration = 0

        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.defaultRate = Float(playbackRate)
        player.volume = Float(volume)
        player.isMuted = isMuted
        player.play()
        player.rate = Float(playbackRate)
        isPlaying = true
    }

    func togglePlayback() {
        guard hasVideo else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if duration > 0 && currentTime >= duration - 0.1 { seek(to: 0) }
            player.defaultRate = Float(playbackRate)
            player.play()
            player.rate = Float(playbackRate)
            isPlaying = true
        }
    }

    func setRate(_ value: Double) {
        playbackRate = min(4, max(0.25, value))
        player.defaultRate = Float(playbackRate)
        if isPlaying { player.rate = Float(playbackRate) }
    }

    func seek(to seconds: Double) {
        guard hasVideo else { return }
        let target = min(max(seconds, 0), duration > 0 ? duration : seconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = target
    }

    func skip(_ seconds: Double) {
        seek(to: currentTime + seconds)
    }

    func toggleMute() {
        isMuted.toggle()
    }
}
