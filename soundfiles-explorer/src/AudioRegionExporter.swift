import Foundation
import AVFoundation

final class AudioRegionExporter {

    enum ExportError: Error, LocalizedError {
        case fileNotReadable
        case bufferAllocationFailed
        case writeFailed(underlying: Error)
        case invalidRegion

        var errorDescription: String? {
            switch self {
            case .fileNotReadable:           return "The source file could not be read."
            case .bufferAllocationFailed:    return "Failed to allocate audio buffer."
            case .writeFailed(let e):        return "Write failed: \(e.localizedDescription)"
            case .invalidRegion:             return "Invalid region: startTime must be less than endTime and within the file duration."
            }
        }
    }

    func exportRegion(from fileInfo: AudioFileInfo, startTime: TimeInterval, endTime: TimeInterval) throws -> URL {
        guard startTime < endTime, startTime >= 0, endTime <= fileInfo.duration else {
            throw ExportError.invalidRegion
        }
        guard fileInfo.url.isFileURL, FileManager.default.fileExists(atPath: fileInfo.url.path) else {
            throw ExportError.fileNotReadable
        }

        let audioFile = try AVAudioFile(forReading: fileInfo.url)
        let startFrame = AVAudioFramePosition(startTime * fileInfo.sampleRate)
        let frameCount = AVAudioFrameCount((endTime - startTime) * fileInfo.sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
            throw ExportError.bufferAllocationFailed
        }

        audioFile.framePosition = startFrame
        try audioFile.read(into: buffer, frameCount: frameCount)

        let sourceName = fileInfo.url.deletingPathExtension().lastPathComponent
        let filename = "\(sourceName)_\(formatTimestamp(startTime))_\(formatTimestamp(endTime)).wav"
        let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        // Scope AVAudioFile so the file handle is flushed and closed before we read it back.
        do {
            let outputFile = try AVAudioFile(forWriting: destURL, settings: audioFile.processingFormat.settings)
            do {
                try outputFile.write(from: buffer)
            } catch {
                throw ExportError.writeFailed(underlying: error)
            }
        }

        try injectMetadata(into: destURL, originalFileInfo: fileInfo, regionStart: startTime)

        return destURL
    }

    // MARK: - Private

    /// Rebuilds the exported WAV at `exportedURL` with BEXT and iXML chunks from the original file.
    private func injectMetadata(into exportedURL: URL, originalFileInfo: AudioFileInfo,
                                 regionStart: TimeInterval) throws {
        let exportedData = try Data(contentsOf: exportedURL)
        let originalData = try Data(contentsOf: originalFileInfo.url)

        guard let fmtChunk  = rawChunk(id: "fmt ", in: exportedData),
              let dataChunk = rawChunk(id: "data", in: exportedData) else { return }

        var output = Data()
        output.append(contentsOf: "RIFF".utf8)
        output.append(uint32LE(0))              // placeholder — fixed up below
        output.append(contentsOf: "WAVE".utf8)
        output.append(fmtChunk)

        if let rawBext = rawChunk(id: "bext", in: originalData) {
            let originalTimeRef = originalFileInfo.bext?.timeReferenceSamples ?? 0
            output.append(updatedBEXT(rawBext, regionStart: regionStart,
                                       sampleRate: originalFileInfo.sampleRate,
                                       originalTimeRef: originalTimeRef))
        }

        if let ixmlChunk = rawChunk(id: "iXML", in: originalData) {
            output.append(ixmlChunk)
        }

        output.append(dataChunk)

        // RIFF size = total file size minus the 8 bytes for "RIFF" + size field
        output.replaceSubrange(4 ..< 8, with: uint32LE(UInt32(output.count - 8)))

        try output.write(to: exportedURL, options: .atomic)
    }

    /// Walks a RIFF/WAVE file and returns a fresh copy of the first chunk matching `id`
    /// (including its 8-byte header and any odd-byte pad).
    private func rawChunk(id: String, in data: Data) -> Data? {
        guard data.count >= 12 else { return nil }
        var offset = 12  // skip RIFF(4) + size(4) + WAVE(4)
        while offset + 8 <= data.count {
            let chunkID = String(bytes: data[offset ..< offset + 4], encoding: .isoLatin1) ?? ""
            let size    = Int(data[offset + 4 ..< offset + 8].withUnsafeBytes {                
                UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self))
            })
            let padded  = size + (size % 2)
            if chunkID == id {
                return Data(data[offset ..< min(offset + 8 + padded, data.count)])
            }
            offset += 8 + padded
        }
        return nil
    }

    /// Returns a copy of `chunk` with the BEXT TimeReference field updated to
    /// `originalTimeRef + regionStart × sampleRate`.
    private func updatedBEXT(_ chunk: Data, regionStart: TimeInterval,
                              sampleRate: Double, originalTimeRef: UInt64) -> Data {
        // TimeRef low/high sit at byte offsets 346/350 from the chunk start
        // (8-byte header + 338-byte offset within BEXT data for the low word).
        guard chunk.count >= 354 else { return chunk }
        var result = chunk
        let newRef = originalTimeRef + UInt64(regionStart * sampleRate)
        result.replaceSubrange(346 ..< 350, with: uint32LE(UInt32(newRef & 0xFFFF_FFFF)))
        result.replaceSubrange(350 ..< 354, with: uint32LE(UInt32((newRef >> 32) & 0xFFFF_FFFF)))
        return result
    }

    private func uint32LE(_ value: UInt32) -> Data {
        var v = value.littleEndian
        return withUnsafeBytes(of: &v) { Data($0) }
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let h  = Int(time) / 3600
        let m  = (Int(time) % 3600) / 60
        let s  = Int(time) % 60
        let ms = Int(time.truncatingRemainder(dividingBy: 1) * 1000)
        return String(format: "%02d-%02d-%02d-%03d", h, m, s, ms)
    }
}
