import Cocoa
import AVFoundation

// MARK: - Audio File Information Helper

struct AudioFileInfo {
    let url: URL
    let duration: TimeInterval
    let sampleRate: Double
    let channelCount: Int
    let format: AVAudioFormat?
    let fileFormat: String
    let bitDepth: Int?
    let bitRate: Double?
    
    init?(url: URL) {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return nil }
        let format = audioFile.processingFormat
        
        self.url = url
        self.format = format
        self.sampleRate = format.sampleRate
        self.channelCount = Int(format.channelCount)
        self.duration = Double(audioFile.length) / sampleRate
        self.fileFormat = url.pathExtension.uppercased()
        
        // Try to get bit depth from format
        if let settings = format.settings[AVLinearPCMBitDepthKey] as? Int {
            self.bitDepth = settings
        } else {
            self.bitDepth = nil
        }
        
        // Calculate approximate bit rate
        if let bitDepth = self.bitDepth {
            self.bitRate = sampleRate * Double(channelCount) * Double(bitDepth)
        } else {
            self.bitRate = nil
        }
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedSampleRate: String {
        if sampleRate >= 1000 {
            return String(format: "%.1f kHz", sampleRate / 1000)
        } else {
            return String(format: "%.0f Hz", sampleRate)
        }
    }
    
    var formattedBitRate: String? {
        guard let bitRate = bitRate else { return nil }
        
        if bitRate >= 1_000_000 {
            return String(format: "%.1f Mbps", bitRate / 1_000_000)
        } else if bitRate >= 1000 {
            return String(format: "%.1f kbps", bitRate / 1000)
        } else {
            return String(format: "%.0f bps", bitRate)
        }
    }
    
    var channelLayout: String {
        switch channelCount {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 4: return "Quad"
        case 6: return "5.1 Surround"
        case 8: return "7.1 Surround"
        default: return "\(channelCount) Channels"
        }
    }
}

// MARK: - Waveform Data Export

extension AudioWaveformView {
    
    /// Export waveform data as JSON for external processing
    func exportWaveformData() -> Data? {
        var data: [String: Any] = [
            "duration": duration,
            "sampleRate": sampleRate,
            "channelCount": channelWaveforms.count,
            "channels": []
        ]
        
        var channelsData: [[String: Any]] = []
        
        for (index, waveform) in channelWaveforms.enumerated() {
            let channelData: [String: Any] = [
                "name": channelNames[index],
                "index": index,
                "samples": waveform
            ]
            channelsData.append(channelData)
        }
        
        data["channels"] = channelsData
        
        return try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
    }
    
    /// Export the current view as a high-resolution image
    func exportAsImage(scale: CGFloat = 2.0) -> NSImage? {
        let scaledSize = NSSize(width: bounds.width * scale, height: bounds.height * scale)
        
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(scaledSize.width),
            pixelsHigh: Int(scaledSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        
        NSGraphicsContext.saveGraphicsState()
        
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current = context
        
        if let cgContext = context?.cgContext {
            cgContext.scaleBy(x: scale, y: scale)
            
            // Draw the view
            layer?.render(in: cgContext)
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        
        return image
    }
}

// MARK: - Keyboard Navigation Extension

extension AudioWaveformView {
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        guard duration > 0 else {
            super.keyDown(with: event)
            return
        }
        
        let modifierFlags = event.modifierFlags
        let isShiftPressed = modifierFlags.contains(.shift)
        let isCommandPressed = modifierFlags.contains(.command)
        
        switch event.keyCode {
        case 123: // Left arrow
            let jumpAmount: TimeInterval = isShiftPressed ? 10 : (isCommandPressed ? 1 : 0.1)
            currentTime = max(0, currentTime - jumpAmount)
            notifySeek()
            
        case 124: // Right arrow
            let jumpAmount: TimeInterval = isShiftPressed ? 10 : (isCommandPressed ? 1 : 0.1)
            currentTime = min(duration, currentTime + jumpAmount)
            notifySeek()
            
        case 49: // Space bar
            // Toggle play/pause
            NotificationCenter.default.post(
                name: NSNotification.Name("AudioWaveformViewTogglePlayback"),
                object: self
            )
            
        case 115: // Home
            currentTime = 0
            notifySeek()
            
        case 119: // End
            currentTime = duration
            notifySeek()
            
        default:
            super.keyDown(with: event)
        }
    }
    
    private func notifySeek() {
        NotificationCenter.default.post(
            name: NSNotification.Name("AudioWaveformViewDidSeek"),
            object: self,
            userInfo: ["time": currentTime]
        )
    }
}

// MARK: - Region Selection Extension

class WaveformRegion {
    var startTime: TimeInterval
    var endTime: TimeInterval
    var color: NSColor
    var label: String?
    
    init(startTime: TimeInterval, endTime: TimeInterval, color: NSColor, label: String? = nil) {
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
        self.label = label
    }
    
    var duration: TimeInterval {
        return endTime - startTime
    }
}

extension AudioWaveformView {
    
    private static var regionsKey: UInt8 = 0
    
    var regions: [WaveformRegion] {
        get {
            return objc_getAssociatedObject(self, &Self.regionsKey) as? [WaveformRegion] ?? []
        }
        set {
            objc_setAssociatedObject(self, &Self.regionsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            needsDisplay = true
        }
    }
    
    func addRegion(_ region: WaveformRegion) {
        var currentRegions = regions
        currentRegions.append(region)
        regions = currentRegions
    }
    
    func clearRegions() {
        regions = []
    }
    
    func drawRegions(in context: CGContext, waveformRect: NSRect) {
        for region in regions {
            let startX = CGFloat(region.startTime) * pixelsPerSecond
            let endX = CGFloat(region.endTime) * pixelsPerSecond
            let width = endX - startX
            
            let regionRect = NSRect(
                x: waveformRect.minX + startX,
                y: waveformRect.minY,
                width: width,
                height: waveformRect.height
            )
            
            // Draw semi-transparent region
            context.saveGState()
            region.color.withAlphaComponent(0.3).setFill()
            context.fill(regionRect)
            
            // Draw border
            region.color.setStroke()
            context.setLineWidth(2)
            context.stroke(regionRect)
            
            // Draw label if present
            if let label = region.label {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: region.color
                ]
                
                let attributedString = NSAttributedString(string: label, attributes: attributes)
                attributedString.draw(at: NSPoint(x: regionRect.minX + 5, y: regionRect.maxY - 20))
            }
            
            context.restoreGState()
        }
    }
}

// MARK: - Audio Processing Utilities

class AudioWaveformGenerator {
    
    static func generateWaveform(
        from url: URL,
        targetPoints: Int,
        channelIndex: Int? = nil
    ) -> [Float]? {
        
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return nil
        }
        let format = audioFile.processingFormat
        
        let totalSamples = Int(audioFile.length)
        let samplesPerPoint = max(1, totalSamples / targetPoints)
        
        var maxValues: [Float] = []
        
        let bufferSize: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else {
            return nil
        }
        
        var sampleCounter = 0
        var currentMax: Float = 0
        
        audioFile.framePosition = 0
        
        while audioFile.framePosition < audioFile.length {
            do {
                try audioFile.read(into: buffer)
                
                let frameLength = Int(buffer.frameLength)
                let channel = channelIndex ?? 0
                
                if let channelData = buffer.floatChannelData?[min(channel, Int(format.channelCount) - 1)] {
                    for frame in 0..<frameLength {
                        let sample = abs(channelData[frame])
                        currentMax = max(currentMax, sample)
                        
                        sampleCounter += 1
                        
                        if sampleCounter >= samplesPerPoint {
                            maxValues.append(currentMax)
                            currentMax = 0
                            sampleCounter = 0
                        }
                    }
                }
                
            } catch {
                print("Error reading audio buffer: \(error)")
                break
            }
        }
        
        if currentMax > 0 {
            maxValues.append(currentMax)
        }
        
        return maxValues
    }
    
    static func normalizeWaveform(_ waveform: [Float]) -> [Float] {
        guard let max = waveform.max(), max > 0 else {
            return waveform
        }
        
        return waveform.map { $0 / max }
    }
    
    static func smoothWaveform(_ waveform: [Float], windowSize: Int = 3) -> [Float] {
        guard windowSize > 1 else { return waveform }
        
        var smoothed: [Float] = []
        let halfWindow = windowSize / 2
        
        for i in 0..<waveform.count {
            let start = max(0, i - halfWindow)
            let end = min(waveform.count, i + halfWindow + 1)
            
            let sum = waveform[start..<end].reduce(0, +)
            let average = sum / Float(end - start)
            smoothed.append(average)
        }
        
        return smoothed
    }
}

// MARK: - Marker Support

struct WaveformMarker {
    let time: TimeInterval
    let label: String
    let color: NSColor
    
    init(time: TimeInterval, label: String, color: NSColor = .yellow) {
        self.time = time
        self.label = label
        self.color = color
    }
}

extension AudioWaveformView {
    
    private static var markersKey: UInt8 = 0
    
    var markers: [WaveformMarker] {
        get {
            return objc_getAssociatedObject(self, &Self.markersKey) as? [WaveformMarker] ?? []
        }
        set {
            objc_setAssociatedObject(self, &Self.markersKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            needsDisplay = true
        }
    }
    
    func addMarker(at time: TimeInterval, label: String, color: NSColor = .yellow) {
        let marker = WaveformMarker(time: time, label: label, color: color)
        var currentMarkers = markers
        currentMarkers.append(marker)
        markers = currentMarkers
    }
    
    func clearMarkers() {
        markers = []
    }
}
