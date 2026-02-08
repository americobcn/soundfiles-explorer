//
//  AudioFileLoader.swift
//  soundfiles-explorer
//
//  Created by opencode on 2/5/26.
//

import Cocoa
import AVFoundation
import CoreMedia

// MARK: - Audio File Info

/// Consolidated information about a loaded audio file

class AudioFileInfo: NSObject {
    @objc let fileName: String
    @objc let url: URL
    @objc let duration: TimeInterval
    let sampleRate: Double
    let channelCount: Int
    let bitDepth: Int
    let playerItem: AVPlayerItem
    let waveformData: [[Float]]
    @objc let scene: String
    @objc let take: String
    @objc let date: String
    @objc let timeCodeStart: String
    let tracksNames: [Int: String]
    let asbd: AudioStreamBasicDescription
    let bext: BEXTMetadata?
    let ixml: IXMLMetadata?
    
    init(url: URL,
         fileName: String,
         duration: TimeInterval,
         sampleRate: Double,
         channelCount: Int,
         bitDepth: Int,
         playerItem: AVPlayerItem,
         waveformData: [[Float]],
         scene: String = "",
         take: String = "",
         date: String = "",
         timeCodeStart: String = "",
         tracksNames: [Int: String],
         asbd: AudioStreamBasicDescription,
         bext: BEXTMetadata?,
         ixml: IXMLMetadata?
    ) {
        self.url = url
        self.fileName = fileName
        self.duration = duration
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        self.playerItem = playerItem
        self.waveformData = waveformData
        self.scene = scene
        self.take = take
        self.date = date
        self.timeCodeStart = timeCodeStart
        self.tracksNames = tracksNames
        self.asbd = asbd
        self.bext = bext
        self.ixml = ixml
        super.init()
    }
}

// MARK: - Audio File Loader

/// Responsible for loading audio files and extracting all necessary data
/// Loads the file once and provides data for playback, waveform display, and metadata
final class AudioFileLoader {
    
    // MARK: - Properties
    
    private let waveformCache: NSCache<NSString, WaveformCacheEntry>
    
    private class WaveformCacheEntry: NSObject {
        let waveforms: [[Float]]
        init(waveforms: [[Float]]) {
            self.waveforms = waveforms
            super.init()
        }
    }
    
    private let audioMetadataReader: AudioMetadataReader?
    private var audioMetadata:AudioMetadata?
    
    // MARK: - Initialization
    
    init(cacheLimit: Int = 1000) {
        waveformCache = NSCache<NSString, WaveformCacheEntry>()
        waveformCache.countLimit = cacheLimit
        audioMetadataReader = AudioMetadataReader()
    }
    
    // MARK: - Public Methods
    
    /// Loads an audio file and extracts all necessary information
    /// - Parameter url: The URL of the audio file to load
    /// - Returns: AudioFileInfo containing playback item, waveform data, and metadata
    /// - Throws: AudioParserError if file cannot be loaded or parsed
    func loadAudioFile(_ url: URL) async throws -> AudioFileInfo {
        // Load audio file for waveform generation
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        
        // Extract basic info from AVAudioFile
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        let duration = Double(audioFile.length) / sampleRate
        
        // Generate or retrieve cached waveform data
        
        let waveformData = try await generateWaveforms(from: audioFile, url: url)
        
                                
        // Create AVURLAsset and extract ASBD for playback and metadata
        let loadOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        let asset = AVURLAsset(url: url, options: loadOptions)
        
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioParserError.noAudioTrack
        }
        
        guard let asbdPointer = try await track.load(.formatDescriptions).first?.audioFormatList.first?.mASBD else {
            throw AudioParserError.malformedMetadata
        }
        
        let asbd = asbdPointer
        let bitDepth = Int(asbd.mBitsPerChannel)
                
        //Load audio metadata
        audioMetadata = try audioMetadataReader?.readAudioMetadata(from: url)
        
        var scene = ""
        var take = ""
        var date = ""
        var timeCodeStart = ""
        var tracksNames = [Int: String]()
        if let ixml = audioMetadata!.ixml, let bext = audioMetadata!.bext {
            date = bext.originationDate
            scene = ixml.scene ?? ""
            take = ixml.take ?? ""
                                                            
            let tcr = ixml.parsedData["TIMECODE_RATE"]!.split(separator: "/")
            if  !tcr.isEmpty {
                timeCodeStart = timecodeFromTimeReference(samples: Int64(bext.timeReferenceSamples),
                                                          sampleRate: Double(sampleRate),
                                                          frameRate: Double(tcr[0])!
                )
            }
            ///Get tracks index and names
            for t in ixml.tracks.enumerated() {
                tracksNames[t.element.index] = t.element.name
            }
        }
        
        /// Create player item for playback
        let playerItem = AVPlayerItem(asset: asset)
        
        return AudioFileInfo(
            url: url,
            fileName: url.deletingPathExtension().lastPathComponent,
            duration: duration,
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitDepth: bitDepth,
            playerItem: playerItem,
            waveformData: waveformData,
            scene: scene,
            take: take,
            date: date,
            timeCodeStart: timeCodeStart,
            tracksNames: tracksNames,
            asbd: asbd,
            bext: audioMetadata?.bext,
            ixml: audioMetadata?.ixml
        )
    }
    
    // MARK: - Private Methods
    
    private func generateWaveforms(from file: AVAudioFile, url: URL) async throws -> [[Float]] {
        let format = file.processingFormat
        let totalSamples = Int(file.length)
        let channelCount = Int(format.channelCount)
        let duration = Double(file.length) / format.sampleRate
        
        // Calculate pixels per second for caching (default 100)
        let pixelsPerSecond: CGFloat = 100
        
        // Check cache first
        let cacheKey = "\(url.absoluteString)-\(pixelsPerSecond)" as NSString
        if let cachedEntry = waveformCache.object(forKey: cacheKey) {
            return cachedEntry.waveforms
        }
        
        // Determine samples per point
        let desiredWaveformPoints = Int(duration * Double(pixelsPerSecond))
        let samplesPerPoint = max(1, totalSamples / desiredWaveformPoints)
        
        var channelMaxValues: [[Float]] = Array(repeating: [], count: channelCount)
        
        // Read audio in chunks
        let bufferSize: AVAudioFrameCount = 32768
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else {
            throw AudioParserError.malformedMetadata
        }
        
        var sampleCounter = 0
        var currentMaxes: [Float] = Array(repeating: 0, count: channelCount)
        
        file.framePosition = 0
        
        while file.framePosition < file.length {
            do {
                try file.read(into: buffer)
                let frameLength = Int(buffer.frameLength)
                
                for frame in 0..<frameLength {
                    for channel in 0..<channelCount {
                        if let channelData = buffer.floatChannelData?[channel] {
                            let sample = abs(channelData[frame])
                            currentMaxes[channel] = max(currentMaxes[channel], sample)
                        }
                    }
                    
                    sampleCounter += 1
                    
                    if sampleCounter >= samplesPerPoint {
                        for channel in 0..<channelCount {
                            channelMaxValues[channel].append(currentMaxes[channel])
                        }
                        currentMaxes = Array(repeating: 0, count: channelCount)
                        sampleCounter = 0
                    }
                }
            } catch {
                break
            }
        }
        
        // Store final values
        for channel in 0..<channelCount {
            if currentMaxes[channel] > 0 {
                channelMaxValues[channel].append(currentMaxes[channel])
            }
        }
        
        // Reverse channel order so Channel 1 appears at top (highest y-position in macOS coordinate system)
        let reversedChannels = channelMaxValues.reversed()
        
        // Cache the waveform data
        waveformCache.setObject(WaveformCacheEntry(waveforms: Array(reversedChannels)), forKey: cacheKey)
        
        return Array(reversedChannels)
    }
    
    
    func timecodeFromTimeReference(samples: Int64, sampleRate: Double, frameRate: Double) -> String {
        // Convert samples to seconds
        let seconds = Double(samples) / sampleRate
        
        // Convert seconds to timecode components
        let totalFrames = Int64(seconds * frameRate)
        let frames = totalFrames % Int64(frameRate)
        let secondsTotal = totalFrames / Int64(frameRate)
        let secs = secondsTotal % 60
        let mins = (secondsTotal / 60) % 60
        let hours = secondsTotal / 3600
        
        return String(format: "%02d:%02d:%02d:%02d", hours, mins, secs, frames)
    }

}
