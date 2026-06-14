import Cocoa
import AVFoundation
import CoreMedia
import AudioToolbox

// MARK: - Channel Mute State

/// Thread-safe holder for the bitmask of enabled audio channels (bit N = channel N audible).
/// Shared between the main thread (UI toggles) and the realtime audio tap thread.
final class ChannelMuteState {
    private let lock = NSLock()
    private var mask: UInt64

    init(mask: UInt64) {
        self.mask = mask
    }

    func setMask(_ newMask: UInt64) {
        lock.lock()
        mask = newMask
        lock.unlock()
    }

    func getMask() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return mask
    }
}

// MARK: - Audio Processing Tap Callbacks

private func channelMuteTapInit(
    _ tap: MTAudioProcessingTap,
    _ clientInfo: UnsafeMutableRawPointer?,
    _ tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    tapStorageOut.pointee = clientInfo
}

private func channelMuteTapFinalize(_ tap: MTAudioProcessingTap) {
    Unmanaged<ChannelMuteState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
}

/// Returns whether `channel` is audible per `mask` (bit N = channel N enabled).
/// Channels >= 64 are treated as disabled, matching `mask`'s `UInt64` width.
private func isChannelEnabled(_ channel: Int, mask: UInt64) -> Bool {
    channel < 64 && (mask & (UInt64(1) << channel)) != 0
}

/// Clamps `value` to [-1, 1] to avoid hard clipping when folded channels sum above full scale.
private func clampedSample(_ value: Float32) -> Float32 {
    min(1, max(-1, value))
}

private func channelMuteTapProcess(
    _ tap: MTAudioProcessingTap,
    _ numberFrames: CMItemCount,
    _ flags: MTAudioProcessingTapFlags,
    _ bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    _ numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    _ flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    var timeRange = CMTimeRange.zero
    let status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, &timeRange, numberFramesOut)
    guard status == noErr else { return }

    let state = Unmanaged<ChannelMuteState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    let mask = state.getMask()

    let bufferList = UnsafeMutableAudioBufferListPointer(bufferListInOut)
    let frameCount = Int(numberFramesOut.pointee)
    guard frameCount > 0 else { return }

    // Fold every enabled channel onto output positions 0 (L) and 1 (R): CoreAudio's
    // final downmix to stereo output only reads positions 0/1 and silently drops
    // the rest when the asset has no defined channel layout, so an enabled channel's
    // audio must be routed here (not just left in place) to be audible.
    if bufferList.count == 1 {
        // Interleaved: one buffer, samples at base[frame * channelCount + channel]
        let buffer = bufferList[0]
        let channelCount = Int(buffer.mNumberChannels)
        guard channelCount > 0, let base = buffer.mData?.assumingMemoryBound(to: Float32.self) else { return }

        for frame in 0..<frameCount {
            let frameBase = frame * channelCount
            var left: Float32 = 0
            var right: Float32 = 0

            for channel in 0..<channelCount where isChannelEnabled(channel, mask: mask) {
                let sample = base[frameBase + channel]
                if channel == 0 {
                    left += sample
                } else if channel == 1 {
                    right += sample
                } else {
                    left += sample
                    right += sample
                }
            }

            base[frameBase] = clampedSample(left)
            if channelCount > 1 {
                base[frameBase + 1] = clampedSample(right)
            }
            if channelCount > 2 {
                for channel in 2..<channelCount {
                    base[frameBase + channel] = 0
                }
            }
        }
    } else {
        // Non-interleaved: one buffer per channel, frameCount samples each
        let channelCount = bufferList.count
        var channelBases: [UnsafeMutablePointer<Float32>?] = []
        channelBases.reserveCapacity(channelCount)
        for channel in 0..<channelCount {
            channelBases.append(bufferList[channel].mData?.assumingMemoryBound(to: Float32.self))
        }

        for frame in 0..<frameCount {
            var left: Float32 = 0
            var right: Float32 = 0

            for channel in 0..<channelCount where isChannelEnabled(channel, mask: mask) {
                guard let channelBase = channelBases[channel] else { continue }
                let sample = channelBase[frame]
                if channel == 0 {
                    left += sample
                } else if channel == 1 {
                    right += sample
                } else {
                    left += sample
                    right += sample
                }
            }

            channelBases[0]?[frame] = clampedSample(left)
            if channelCount > 1 {
                channelBases[1]?[frame] = clampedSample(right)
            }
        }

        if channelCount > 2 {
            for channel in 2..<channelCount {
                if let data = bufferList[channel].mData {
                    memset(data, 0, Int(bufferList[channel].mDataByteSize))
                }
            }
        }
    }
}

/// Manages audio playback for the soundfiles explorer application
class AudioPlaybackManager: NSObject {
    // MARK: - Properties
    private var player: AVPlayer?
    private var channelMuteState: ChannelMuteState?


    // MARK: - Public Properties
    var currentTime: TimeInterval = 0

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
        player?.automaticallyWaitsToMinimizeStalling = false
    }


    // MARK: - Public Methods

    /// Load a file for playback, applying a per-channel audio mute mask via an MTAudioProcessingTap.
    /// Channels not in `enabledChannels` are silenced; play/pause/seek/currentTime are unaffected.
    @MainActor
    func setAudioURL(_ url: URL, channelCount: Int, enabledChannels: Set<Int>, duration: Float64) async {
        stop()

        let mask = Self.makeMask(enabledChannels: enabledChannels, channelCount: channelCount)
        let state = ChannelMuteState(mask: mask)

        let asset = AVURLAsset(url: url)
        var track: AVAssetTrack?
        if let tracks = try? await asset.loadTracks(withMediaType: .audio) {
            track = tracks.first
        }

        var item: AVPlayerItem?
        if let track = track, let tap = Self.makeChannelMuteTap(state: state) {
            let inputParams = AVMutableAudioMixInputParameters(track: track)
            inputParams.audioTapProcessor = tap

            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = [inputParams]

            let playerItem = AVPlayerItem(asset: asset)
            playerItem.audioMix = audioMix
            item = playerItem
        }

        channelMuteState = state
        player?.replaceCurrentItem(with: item ?? AVPlayerItem(url: url))
        self.duration = duration
    }

    /// Update which channels are audible for the currently loaded item.
    func setEnabledChannels(_ enabledChannels: Set<Int>, channelCount: Int) {
        let mask = Self.makeMask(enabledChannels: enabledChannels, channelCount: channelCount)
        channelMuteState?.setMask(mask)
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
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            if finished {
                self?.currentTime = time
            }
        }
    }

    /// Set playback rate
    // func setRate(_ rate: Float) {
    //     player?.rate = rate
    // }


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

    // MARK: - Private Methods

    private static func makeMask(enabledChannels: Set<Int>, channelCount: Int) -> UInt64 {
        var mask: UInt64 = 0
        for channel in 0..<min(channelCount, 64) where enabledChannels.contains(channel) {
            mask |= (UInt64(1) << channel)
        }
        return mask
    }

    private static func makeChannelMuteTap(state: ChannelMuteState) -> MTAudioProcessingTap? {
        let clientInfo = Unmanaged.passRetained(state).toOpaque()

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: clientInfo,
            init: channelMuteTapInit,
            finalize: channelMuteTapFinalize,
            prepare: nil,
            unprepare: nil,
            process: channelMuteTapProcess
        )

        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tap
        )

        guard status == noErr, let tap = tap else {
            Unmanaged<ChannelMuteState>.fromOpaque(clientInfo).release()
            return nil
        }

        return tap
    }
}
