import Cocoa
import AVFoundation

/// Manages audio playback for the soundfiles explorer application
class AudioPlaybackManager: NSObject {
    // MARK: - Properties
    private var player: AVPlayer?
    
    
    // MARK: - Public Properties
    var currentTime: TimeInterval = 0 {
        didSet {
            print("APM old value: \(oldValue), didSet: \(currentTime)")
            // Notify observers of time change
            NotificationCenter.default.post(
                name: NSNotification.Name("AudioPlaybackTimeChanged"),
                object: nil,
                userInfo: ["time": currentTime]
            )
        }
    }

    var isPlaying: Bool = false {
        didSet {
            // Notify observers of play state change
            NotificationCenter.default.post(
                name: NSNotification.Name("AudioPlaybackStateChanged"),
                object: self,
                userInfo: ["isPlaying": isPlaying]
            )
        }
    }
    
    var duration: Float64 = 0
        
    var rate: Float {
        get {
            guard let pl = player else { return 0 }
            return pl.rate
        }
        set {
            guard let pl = player else { return }
            pl.rate = newValue
        }
    }
    
    
    // MARK: - Initialization
    override init() {
        super.init()
        player = AVPlayer()
    }


    // MARK: - Public Methods

    /// Set the player item for playback
    func setPlayerItem(_ item: AVPlayerItem, duration: Float64) {
        player?.replaceCurrentItem(with: item)
        
        // Store audio properties
        self.duration = duration
    }

    /// Play the audio
    func play() {
        player?.play()
        isPlaying = true
    }

    /// Pause the audio
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Stop the audio and reset to start
    func stop() {
        player?.pause()
        player?.seek(to: CMTime.zero)
        isPlaying = false
        currentTime = 0
    }
            
    
    /// Seek to a specific time
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 1)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            if finished {
                self?.currentTime = time
            }
        }
    }

    /// Set playback rate
    func setRate(_ rate: Float) {
        player?.rate = rate
    }
    
    
    /// Get current playback time directly from AVPlayer for lowest latency
    /// Use this for displayLink updates to ensure tight audio-visual sync
    func getCurrentTimeDirect() -> TimeInterval {
        guard let player = player else { return 0 }
        return CMTimeGetSeconds(player.currentTime())
    }

    /// Get current player state
    func getPlayerState() -> AVPlayer.TimeControlStatus {
        guard let avplayer = player else { return .paused }
        return avplayer.timeControlStatus
    }

    /// Cleanup resources
    func cleanup() {
        player = nil
    }
}
