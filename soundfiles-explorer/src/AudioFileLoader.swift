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
    @objc var duration: TimeInterval = 0
    var sampleRate: Double = 0
    var channelCount: Int = 0
    var bitDepth: Int = 0
    var playerItem: AVPlayerItem?
    var waveformData: [[Float]]?
    var isWaveformLoading: Bool = false
    var isMetadataLoading: Bool = true
    @objc var scene: String = ""
    @objc var take: String = ""
    @objc var date: String = ""
    @objc var timeCodeStart: String = ""
    var tracksNames: [Int: String] = [:]
    var asbd: AudioStreamBasicDescription?
    var bext: BEXTMetadata?
    var ixml: IXMLMetadata?
    
    init(url: URL) {
        self.url = url
        self.fileName = url.deletingPathExtension().lastPathComponent
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
    
    // MARK: - Initialization
    
    init(cacheLimit: Int = 1000) {
        waveformCache = NSCache<NSString, WaveformCacheEntry>()
        waveformCache.countLimit = cacheLimit
        audioMetadataReader = AudioMetadataReader()
    }
    
    // MARK: - Public Methods
    
    /// Creates a basic AudioFileInfo with just the URL and filename
    /// This returns synchronously and immediately
    /// - Parameter url: The URL of the audio file
    /// - Returns: AudioFileInfo with minimal info (just filename and URL)
    func createFileInfo(url: URL) -> AudioFileInfo {
        let fileInfo = AudioFileInfo(url: url)
        
        // Create playerItem IMMEDIATELY for playback (doesn't need metadata)
        let asset = AVURLAsset(url: url)
        fileInfo.playerItem = AVPlayerItem(asset: asset)
        
        return fileInfo
    }
    
    /// Loads metadata and waveforms for an existing AudioFileInfo
    /// This runs in background and updates the fileInfo object directly
    /// - Parameter fileInfo: The AudioFileInfo to load data into
    func loadMetadataAndWaveforms(for fileInfo: AudioFileInfo) async {
        await loadFileMetadataAndWaveforms(fileInfo: fileInfo)
    }
    
    // MARK: - Private Methods
    
    /// Loads all file metadata and waveforms in the background
    /// Uses @concurrent to force execution on background thread
    // @concurrent
    private func loadFileMetadataAndWaveforms(fileInfo: AudioFileInfo) async {
        do {
            // With @concurrent, this blocking call runs on background thread
            // Load audio file for basic info
            let audioFile = try AVAudioFile(forReading: fileInfo.url)
            let format = audioFile.processingFormat
            
            // Extract basic info from AVAudioFile
            fileInfo.sampleRate = format.sampleRate
            fileInfo.channelCount = Int(format.channelCount)
            fileInfo.duration = Double(audioFile.length) / fileInfo.sampleRate
            
            // Create AVURLAsset and extract ASBD for playback and metadata
            let loadOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            let asset = AVURLAsset(url: fileInfo.url, options: loadOptions)
            
            guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
                throw AudioParserError.noAudioTrack
            }
            
            guard let asbdPointer = try await track.load(.formatDescriptions).first?.audioFormatList.first?.mASBD else {
                throw AudioParserError.malformedMetadata
            }
            
            fileInfo.asbd = asbdPointer
            fileInfo.bitDepth = Int(asbdPointer.mBitsPerChannel)
            
            // Load audio metadata
            if let audioMetadata = try audioMetadataReader?.readAudioMetadata(from: fileInfo.url) {
                fileInfo.bext = audioMetadata.bext
                fileInfo.ixml = audioMetadata.ixml
                
                if let ixml = audioMetadata.ixml, let bext = audioMetadata.bext {
                    fileInfo.date = bext.originationDate
                    fileInfo.scene = ixml.scene ?? ""
                    fileInfo.take = ixml.take ?? ""
                    
                    let tcr = ixml.parsedData["TIMECODE_RATE"]!.split(separator: "/")
                    if !tcr.isEmpty {
                        fileInfo.timeCodeStart = timecodeFromTimeReference(
                            samples: Int64(bext.timeReferenceSamples),
                            sampleRate: Double(fileInfo.sampleRate),
                            frameRate: Double(tcr[0])!
                        )
                    }
                    
                    // Get tracks index and names
                    for t in ixml.tracks.enumerated() {
                        fileInfo.tracksNames[t.element.index] = t.element.name
                    }
                }
            }
            
            // Mark metadata loading complete
            fileInfo.isMetadataLoading = false
            
            // Post notification that metadata is loaded
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("FileMetadataLoaded"),
                    object: self,
                    userInfo: ["url": fileInfo.url]
                )
            }
            
            // Start waveform generation in a SEPARATE parallel task
            // This allows metadata to display immediately while waveforms generate in background
            Task {
                await generateWaveformsInBackground(audioFile: audioFile, fileInfo: fileInfo)
            }
            
        } catch {
            print("Error loading file metadata for \(fileInfo.url.lastPathComponent): \(error)")
            fileInfo.isMetadataLoading = false
            fileInfo.isWaveformLoading = false
        }
    }
    
    /// Generates waveforms in a separate background task
    private func generateWaveformsInBackground(audioFile: AVAudioFile, fileInfo: AudioFileInfo) async {
        do {
            fileInfo.isWaveformLoading = true
            let waveformData = try await generateWaveforms(from: audioFile, url: fileInfo.url)
            fileInfo.waveformData = waveformData
            fileInfo.isWaveformLoading = false
            
            // Post notification that waveforms are ready
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("WaveformGenerationCompleted"),
                    object: self,
                    userInfo: ["url": fileInfo.url, "waveformData": waveformData]
                )
            }
        } catch {
            print("Error generating waveforms for \(fileInfo.url.lastPathComponent): \(error)")
            fileInfo.isWaveformLoading = false
        }
    }
    
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
        let bufferSize: AVAudioFrameCount = 2048
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
        waveformCache.setObject(WaveformCacheEntry(waveforms: Array(channelMaxValues)), forKey: cacheKey)
        
        return Array(channelMaxValues)
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
