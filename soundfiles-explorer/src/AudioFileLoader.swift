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
    var formatID: String = ""
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
    var sourceFolderURL: URL? = nil
    var projectID: UUID? = nil
    
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
    
    nonisolated(unsafe) private let waveformCache: NSCache<NSString, WaveformCacheEntry>
    private let diskCache = WaveformDiskCache()

    private class WaveformCacheEntry: NSObject {
        nonisolated let waveforms: [[Float]]
        nonisolated init(waveforms: [[Float]]) {
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
    func createFileInfo(url: URL)  -> AudioFileInfo {
        return AudioFileInfo(url: url)
    }
    
    /// Loads metadata and waveforms for an existing AudioFileInfo
    /// This runs in background and updates the fileInfo object directly
    /// - Parameter fileInfo: The AudioFileInfo to load data into
    nonisolated func loadMetadataAndWaveforms(for fileInfo: AudioFileInfo) async {
        await loadFileMetadataAndWaveforms(fileInfo: fileInfo)
    }

    nonisolated func loadMetadataAndWaveforms(forBatch fileInfos: [AudioFileInfo], maxConcurrent: Int = 3) async {
        await withTaskGroup(of: Void.self) { group in
            var inFlight = 0
            for info in fileInfos {
                if inFlight >= maxConcurrent {
                    await group.next()
                    inFlight -= 1
                }
                group.addTask { await self.loadMetadataAndWaveforms(for: info) }
                inFlight += 1
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Loads all file metadata and waveforms in the background
    private nonisolated func loadFileMetadataAndWaveforms(fileInfo: AudioFileInfo) async {
        do {
            let audioFile = try AVAudioFile(forReading: fileInfo.url)
            // let format = audioFile.processingFormat
            // let sampleRate = format.sampleRate
            // let channelCount = Int(format.channelCount)
            // let duration = Double(audioFile.length) / sampleRate
            // let asbd = format.streamDescription.pointee
            
            let audioAsset = AVURLAsset(url: fileInfo.url)
            let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio)
            let formatDescription = try await audioTrack.first!.load(.formatDescriptions).first!
            let asbd = formatDescription.audioStreamBasicDescription
            let bitDepth = Int(asbd!.mBitsPerChannel)
            let sampleRate = asbd!.mSampleRate
            let channelCount = Int(asbd!.mChannelsPerFrame)
            let duration = try await audioAsset.load(.duration)
            let formatID = formatDescription.mediaSubType
            
            await MainActor.run {
                fileInfo.sampleRate = sampleRate
                fileInfo.channelCount = channelCount
                fileInfo.duration = duration.seconds
                fileInfo.asbd = asbd
                fileInfo.bitDepth = bitDepth
                fileInfo.formatID = formatID.description                
            }
            guard let audioMetadata = try audioMetadataReader?.readAudioMetadata(from: fileInfo.url) else {
                await MainActor.run { fileInfo.isMetadataLoading = false }
                return
            }

            // Compute all derived values locally (nonisolated, background)
            let bext = audioMetadata.bext
            let ixml = audioMetadata.ixml
            let date = bext?.originationDate ?? ""
            let scene = ixml?.scene ?? ""
            let take = ixml?.take ?? ""
            var tracksNames: [Int: String] = [:]
            for t in ixml?.tracks ?? [] {
                if let name = t.name { tracksNames[t.index] = name }
            }

            var timeCodeStart = ""
            if let tcr = ixml?.parsedData["TIMECODE_RATE"]?.split(separator: "/"),
               !tcr.isEmpty,
               let rate = Double(tcr[0]),
               let samples = bext.map({ Int64($0.timeReferenceSamples) }) {
                timeCodeStart = timecodeFromTimeReference(samples: samples,
                                                          sampleRate: sampleRate,
                                                          frameRate: rate)
            }
            
            let trNames = tracksNames
            let tcrCodeStart = timeCodeStart
            
            await MainActor.run {
                fileInfo.bext = bext
                fileInfo.ixml = ixml
                fileInfo.date = date
                fileInfo.scene = scene
                fileInfo.take = take
                fileInfo.tracksNames = trNames
                fileInfo.timeCodeStart = tcrCodeStart
                fileInfo.isMetadataLoading = false
            }

            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("FileMetadataLoaded"),
                    object: self,
                    userInfo: ["url": fileInfo.url]
                )
            }

            await generateWaveformsInBackground(audioFile: audioFile, fileInfo: fileInfo)

        } catch {
            print("Error loading file metadata for \(fileInfo.url.lastPathComponent): \(error)")
            await MainActor.run {
                fileInfo.isMetadataLoading = false
                fileInfo.isWaveformLoading = false
            }
        }
    }
    
    /// Generates waveforms in a separate background task
    private nonisolated func generateWaveformsInBackground(audioFile: AVAudioFile, fileInfo: AudioFileInfo) async {
        do {
            await MainActor.run { fileInfo.isWaveformLoading = true }
            let waveformData = try await generateWaveforms(from: audioFile, url: fileInfo.url)
            await MainActor.run {
                fileInfo.waveformData = waveformData
                fileInfo.isWaveformLoading = false
            }
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("WaveformGenerationCompleted"),
                    object: self,
                    userInfo: ["url": fileInfo.url, "waveformData": waveformData]
                )
            }
        } catch {
            print("Error generating waveforms for \(fileInfo.url.lastPathComponent): \(error)")
            await MainActor.run { fileInfo.isWaveformLoading = false }
        }
    }
    
    private nonisolated func generateWaveforms(from file: AVAudioFile, url: URL) async throws -> [[Float]] {
        let format = file.processingFormat
        let totalSamples = Int(file.length)
        let channelCount = Int(format.channelCount)
        let duration = Double(file.length) / format.sampleRate
        
        // Calculate pixels per second for caching (default 100)
        let pixelsPerSecond: CGFloat = 100
        
        // L1: in-memory cache
        let cacheKey = "\(url.absoluteString)-\(pixelsPerSecond)" as NSString
        if let cachedEntry = waveformCache.object(forKey: cacheKey) {
            return cachedEntry.waveforms
        }

        // L2: disk cache
        if let cached = diskCache.load(for: url) {
            waveformCache.setObject(WaveformCacheEntry(waveforms: cached), forKey: cacheKey)
            return cached
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
        var chunkCount = 0

        file.framePosition = 0

        while file.framePosition < file.length {
            chunkCount += 1
            if chunkCount.isMultiple(of: 16) { await Task.yield() }
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
        
        let waveforms = Array(channelMaxValues)

        // Cache the waveform data (L1 + L2)
        waveformCache.setObject(WaveformCacheEntry(waveforms: waveforms), forKey: cacheKey)
        diskCache.save(waveforms, for: url)

        return waveforms
    }
    
    
    nonisolated func timecodeFromTimeReference(samples: Int64, sampleRate: Double, frameRate: Double) -> String {
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

// MARK: - Waveform Disk Cache

/// Binary on-disk waveform cache stored in ~/Library/Caches/<BundleID>/waveforms/
/// Cache entries are invalidated when the source file's modification date changes.
///
/// Binary format:
///   Bytes 0-3:   Magic "WFCX"
///   Bytes 4-7:   Int32 LE: channel count
///   Bytes 8-11:  Int32 LE: samples per channel
///   Bytes 12+:   Float32 values, channel 0 first, then channel 1, etc.
private final class WaveformDiskCache {

    nonisolated private static let magic: [UInt8] = [0x57, 0x46, 0x43, 0x58] // "WFCX"
    private let cacheDirectory: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "soundfiles-explorer"
        cacheDirectory = base.appendingPathComponent(bundleID).appendingPathComponent("waveforms")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public

    nonisolated func load(for audioURL: URL) -> [[Float]]? {
        let fileURL = cacheFileURL(for: audioURL)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return decode(data)
    }

    nonisolated func save(_ waveforms: [[Float]], for audioURL: URL) {
        let fileURL = cacheFileURL(for: audioURL)
        let data = encode(waveforms)
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Private

    private nonisolated func cacheFileURL(for audioURL: URL) -> URL {
        let modDate = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.modificationDate] as? Date) ?? Date.distantPast
        let key = "\(audioURL.absoluteString)-\(modDate.timeIntervalSinceReferenceDate)"
        let hashValue = abs(key.hashValue)
        return cacheDirectory.appendingPathComponent("\(hashValue).wfcache")
    }

    private nonisolated func encode(_ waveforms: [[Float]]) -> Data {
        var data = Data()
        data.append(contentsOf: WaveformDiskCache.magic)
        var channelCount = Int32(waveforms.count)
        data.append(contentsOf: withUnsafeBytes(of: &channelCount) { Array($0) })
        var samplesPerChannel = Int32(waveforms.first?.count ?? 0)
        data.append(contentsOf: withUnsafeBytes(of: &samplesPerChannel) { Array($0) })
        for channel in waveforms {
            var mutableChannel = channel
            data.append(contentsOf: mutableChannel.withUnsafeMutableBytes { Array($0) })
        }
        return data
    }

    private nonisolated func decode(_ data: Data) -> [[Float]]? {
        guard data.count >= 12 else { return nil }
        let magic = [UInt8](data[0..<4])
        guard magic == WaveformDiskCache.magic else { return nil }
        let channelCount = Int(data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) })
        let samplesPerChannel = Int(data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Int32.self) })
        guard channelCount > 0, samplesPerChannel > 0 else { return nil }
        let expectedSize = 12 + channelCount * samplesPerChannel * 4
        guard data.count >= expectedSize else { return nil }
        var waveforms: [[Float]] = []
        for i in 0..<channelCount {
            let offset = 12 + i * samplesPerChannel * 4
            let channel: [Float] = data.withUnsafeBytes { ptr in
                let floatPtr = ptr.baseAddress!.advanced(by: offset).assumingMemoryBound(to: Float.self)
                return Array(UnsafeBufferPointer(start: floatPtr, count: samplesPerChannel))
            }
            waveforms.append(channel)
        }
        return waveforms
    }
}
