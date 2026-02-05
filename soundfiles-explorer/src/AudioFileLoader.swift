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
struct AudioFileInfo {
    let url: URL
    let duration: TimeInterval
    let sampleRate: Double
    let channelCount: Int
    let bitDepth: Int
    let playerItem: AVPlayerItem
    let waveformData: [[Float]]
    let asbd: AudioStreamBasicDescription
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
    
    // MARK: - Initialization
    
    init(cacheLimit: Int = 10) {
        waveformCache = NSCache<NSString, WaveformCacheEntry>()
        waveformCache.countLimit = cacheLimit
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
        
        // Create player item for playback
        let playerItem = AVPlayerItem(asset: asset)
        
        return AudioFileInfo(
            url: url,
            duration: duration,
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitDepth: bitDepth,
            playerItem: playerItem,
            waveformData: waveformData,
            asbd: asbd
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
        let bufferSize: AVAudioFrameCount = 16384
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
        
        // Cache the waveform data
        waveformCache.setObject(WaveformCacheEntry(waveforms: channelMaxValues), forKey: cacheKey)
        
        return channelMaxValues
    }
}
