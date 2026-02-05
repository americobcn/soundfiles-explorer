import Cocoa
import AVFoundation

/// Manages audio playback for the soundfiles explorer application
class AudioPlaybackManager: NSObject {
    // MARK: - Properties
    private var player: AVPlayer?
    private var currentTimeObserver: Any?
    private var isObserving = false

    
    // MARK: - Public Properties
    var currentTime: TimeInterval = 0 {
        didSet {
            // Notify observers of time change
            NotificationCenter.default.post(
                name: NSNotification.Name("AudioPlaybackTimeChanged"),
                object: self,
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

    // Basic Audio Info
    var channelCount: Int = 0
    var sampleRate: Double = 0
    var bitsPerChannel: Int = 0
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
    func setPlayerItem(_ item: AVPlayerItem, duration: Float64, channelCount: Int, sampleRate: Double, bitsPerChannel: Int) {
        // Remove previous observer if exists
        if isObserving, let observer = currentTimeObserver {
            player?.removeTimeObserver(observer)
            isObserving = false
        }

        player?.replaceCurrentItem(with: item)
        
        // Store audio properties
        self.duration = duration
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.bitsPerChannel = bitsPerChannel
        
        print("AudioPlaybackManager: Set player item")
        print("Duration: \(duration)")
        print("Channel count: \(channelCount)")
        print("SampleRate: \(sampleRate)")
        print("Bits depth: \(bitsPerChannel)")
        
        // Add time observer on background queue to avoid blocking main thread
        let processingQueue = DispatchQueue(label: "com.audio.timeObserver", qos: .userInitiated)
        currentTimeObserver = player?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 30), queue: processingQueue) { [weak self] time in
            guard let self = self else { return }
            let timeValue = CMTimeGetSeconds(time)
            DispatchQueue.main.async {
                self.currentTime = timeValue
            }
        }
        isObserving = true
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

    /// Get current playback time
    func getCurrentTime() -> TimeInterval {
        return currentTime
    }

    /// Get current player state
    func getPlayerState() -> AVPlayer.TimeControlStatus {
        guard let avplayer = player else { return .paused }
        return avplayer.timeControlStatus
    }

    /// Cleanup resources
    func cleanup() {
        if isObserving, let observer = currentTimeObserver {
            player?.removeTimeObserver(observer)
            isObserving = false
        }
        player = nil
    }
}
