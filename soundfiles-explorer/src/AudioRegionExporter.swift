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

        let outputFile = try AVAudioFile(forWriting: destURL, settings: audioFile.processingFormat.settings)

        do {
            try outputFile.write(from: buffer)
        } catch {
            throw ExportError.writeFailed(underlying: error)
        }

        return destURL
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let h  = Int(time) / 3600
        let m  = (Int(time) % 3600) / 60
        let s  = Int(time) % 60
        let ms = Int(time.truncatingRemainder(dividingBy: 1) * 1000)
        return String(format: "%02d-%02d-%02d-%03d", h, m, s, ms)
    }
}
