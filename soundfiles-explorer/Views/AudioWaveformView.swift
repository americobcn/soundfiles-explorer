import Cocoa
import AVFoundation

/// A custom NSView that displays audio waveforms with multi-channel support,
/// playback cursor, and time ruler
class AudioWaveformView: NSView {
    
    // MARK: - Properties
    
    /// Audio file properties
    var duration: TimeInterval = 0
    var sampleRate: Double = 0
    
    
    /// Waveform data for each channel
    var channelWaveforms: [[Float]] = []
    private(set) var channelNames: [String] = []
    
    /// Playback state
    var currentTime: TimeInterval = 0 {
        didSet {
            needsDisplay = true
        }
    }
    
    var isPlaying: Bool = false
    
    /// Waveform caching using NSCache for thread-safe, automatic eviction
    private static let waveformCache: NSCache<NSString, WaveformCacheEntry> = {
        let cache = NSCache<NSString, WaveformCacheEntry>()
        cache.countLimit = 10
        return cache
    }()
    
    /// Wrapper class for cache values since NSCache requires NSObject
    private class WaveformCacheEntry: NSObject {
        let waveforms: [[Float]]
        init(waveforms: [[Float]]) {
            self.waveforms = waveforms
            super.init()
        }
    }
    
    /// Visual customization
    var backgroundColor: NSColor = NSColor(calibratedWhite: 0.35, alpha: 1.0)
    var waveformColors: [NSColor] = [
        NSColor(calibratedRed: 0.2, green: 0.6, blue: 1.0, alpha: 0.8),
        NSColor(calibratedRed: 1.0, green: 0.4, blue: 0.4, alpha: 0.8),
        NSColor(calibratedRed: 0.4, green: 1.0, blue: 0.4, alpha: 0.8),
        NSColor(calibratedRed: 0.6, green: 0.3, blue: 0.2, alpha: 0.8),
        NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.7, alpha: 0.8),
        NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.1, alpha: 0.8),
        NSColor(calibratedRed: 1.0, green: 0.6, blue: 0.5, alpha: 0.8)
    ]
    var cursorColor: NSColor = NSColor(calibratedRed: 1.0, green: 0.3, blue: 0.3, alpha: 0.9)
    var gridColor: NSColor = NSColor(calibratedWhite: 0.3, alpha: 0.5)
    var textColor: NSColor = .white
    
    /// Layout constants
    private let rulerHeight: CGFloat = 20
    private let channelSpacing: CGFloat = 1
    // let channelLabelWidth: CGFloat = 0
    private let minChannelHeight: CGFloat = 60
    private let maxChannelHeight: CGFloat = 100
    private(set) var channelHeight: CGFloat = 60

    /// Zoom and scroll
    var pixelsPerSecond: CGFloat = 100 {
        didSet {
            needsDisplay = true
        }
    }

    var scrollOffset: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }

            
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        print("AudioWavformView: override init")
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("AudioWavformView: required init")
        setupView()
    }
                
    private func setupView() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.borderColor = NSColor.red.cgColor
        layer?.borderWidth = 1
    }
    
    
    // MARK: - Audio Loading
    
    /// Sets waveform data directly from pre-loaded audio file
    /// - Parameters:
    ///   - waveformData: The pre-generated waveform data for each channel
    ///   - duration: The duration of the audio file in seconds
    ///   - sampleRate: The sample rate of the audio file
    ///   - channelCount: The number of audio channels
    func setWaveformData(_ waveformData: [[Float]], duration: TimeInterval, sampleRate: Double, channelCount: Int, names: [Int: String]) {
        self.channelWaveforms = waveformData
        self.duration = duration
        self.sampleRate = sampleRate
        
        channelNames = Array(repeating: "", count: channelCount)
        for (idx, _) in channelWaveforms.enumerated() {
            if names[idx + 1] != nil && names[idx + 1]?.isEmpty == false {
                channelNames[idx] = "\(names[idx + 1]!)\nCh \(idx + 1)"
            } else {
                channelNames[idx] = "Ch \(idx + 1)"
            }
        }
                        
        
        // Cache the waveform data
        let cacheKey = "\(duration)-\(sampleRate)-\(channelCount)-\(pixelsPerSecond)" as NSString
        Self.waveformCache.setObject(WaveformCacheEntry(waveforms: waveformData), forKey: cacheKey)
        
        needsDisplay = true
        updateContentSize()
    }

    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw background
        backgroundColor.setFill()
        context.fill(bounds)
        
        // Draw Time ruler
        // drawTimeRuler(in: context)
        
        // Calculate layout
        let channelCount = channelWaveforms.count
        guard channelCount > 0 else {
            drawEmptyState(in: context)
            return
        }
        
        // Calculate starting Y to attach channels to top when content fits
        let totalContentHeight = intrinsicContentSize.height
        let startY = max(0, bounds.height - totalContentHeight)
        
        // Draw each channel
        for (index, waveform) in channelWaveforms.enumerated() {
            let yPosition = startY + channelSpacing + CGFloat(index) * (channelHeight + channelSpacing)
            let channelRect = NSRect(
                x: 0, // channelLabelWidth
                y: yPosition,
                width: bounds.width, // - channelLabelWidth
                height: channelHeight
            )
            
            // Draw channel background
            NSColor(calibratedWhite: 0.1, alpha: 1.0).setFill()
            context.fill(channelRect)
            
            // Draw waveform
            let color = waveformColors[index % waveformColors.count]
            drawWaveform(waveform, in: channelRect, color: color, context: context)
        }
        
        // Draw playback cursor
        drawPlaybackCursor(in: context)
        updateContentSize()
    }
    
    private func drawEmptyState(in context: CGContext) {
        let message = "No audio file loaded"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: textColor.withAlphaComponent(0.5)
        ]
        
        let attributedString = NSAttributedString(string: message, attributes: attributes)
        let size = attributedString.size()
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        
        attributedString.draw(at: point)
    }
    
    private func drawTimeRuler(in context: CGContext) {
        let rulerRect = NSRect(x: 0, y: self.bounds.height, width: bounds.width , height: rulerHeight) //
        
        // Draw ruler background
        NSColor(calibratedWhite: 0.2, alpha: 1.0).setFill()
        context.fill(rulerRect)
        
        // Draw time markers
        let visibleWidth = rulerRect.width
        let secondsVisible = visibleWidth / pixelsPerSecond
        
        // Determine marker interval (1s, 5s, 10s, 30s, 60s, etc.)
        let intervals: [TimeInterval] = [1, 5, 10, 30, 60, 300, 600, 3600]
        var markerInterval: TimeInterval = 1
        for interval in intervals {
            if pixelsPerSecond * CGFloat(interval) >= 50 {
                markerInterval = interval
                break
            }
        }
        
        let startTime = TimeInterval(scrollOffset / pixelsPerSecond)
        let endTime = startTime + secondsVisible
        
        let firstMarker = floor(startTime / markerInterval) * markerInterval
        var time = firstMarker
        
        while time <= endTime {
            let x = CGFloat(time - startTime) * pixelsPerSecond  // channelLabelWidth +
            
            if  x <= bounds.width { // x >= channelLabelWidth &&
                // Draw tick
                gridColor.setStroke()
                context.setLineWidth(1)
                context.move(to: CGPoint(x: x, y: bounds.height - rulerHeight))
                context.addLine(to: CGPoint(x: x, y: bounds.height))
                context.strokePath()
                
                // Draw time label
                let timeString = formatTime(time)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: textColor
                ]
                
                let attributedString = NSAttributedString(string: timeString, attributes: attributes)
                let size = attributedString.size()
                attributedString.draw(at: NSPoint(x: x - size.width / 2, y: bounds.height - rulerHeight + 5))
            }
            
            time += markerInterval
        }
    }
    
    private func drawChannelLabel(_ label: String, at point: NSPoint, in context: CGContext) {        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: textColor
        ]
        
        let attributedString = NSAttributedString(string: label, attributes: attributes)
        let size = attributedString.size()
        attributedString.draw(at: NSPoint(x: point.x, y: point.y - size.height / 2))
        
    }
    
    
    private func drawWaveform(_ waveform: [Float], in rect: NSRect, color: NSColor, context: CGContext) {
        guard !waveform.isEmpty else { return }
        
        let midY = rect.midY
        let maxAmplitude = rect.height / 2 - 2
        
        context.saveGState()
        context.clip(to: rect)
        
        // Create path for waveform
        let path = NSBezierPath()
        
        for (index, value) in waveform.enumerated() {
            let x = rect.minX + CGFloat(index) * (rect.width / CGFloat(waveform.count))
            let amplitude = CGFloat(value) * maxAmplitude
            
            if index == 0 {
                path.move(to: NSPoint(x: x, y: midY - amplitude))
            } else {
                path.line(to: NSPoint(x: x, y: midY - amplitude))
            }
        }
        
        // Mirror the waveform below the center line
        for index in (0..<waveform.count).reversed() {
            let x = rect.minX + CGFloat(index) * (rect.width / CGFloat(waveform.count))
            let amplitude = CGFloat(waveform[index]) * maxAmplitude
            path.line(to: NSPoint(x: x, y: midY + amplitude))
        }
        
        path.close()
        
        // Fill waveform
        color.setFill()
        path.fill()
        
        // Draw center line
        gridColor.setStroke()
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: rect.minX, y: midY))
        context.addLine(to: CGPoint(x: rect.maxX, y: midY))
        context.strokePath()
        
        context.restoreGState()
        
    }
    
    private func drawPlaybackCursor(in context: CGContext) {
        guard duration > 0 else { return }
        
        let startTime = TimeInterval(scrollOffset / pixelsPerSecond)
        let x = CGFloat(currentTime - startTime) * pixelsPerSecond // channelLabelWidth +
        
        // Only draw if cursor is visible
        if  x <= bounds.width {  // x >= channelLabelWidth &&
            context.saveGState()
            
            // Draw cursor line
            cursorColor.setStroke()
            context.setLineWidth(2)
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: bounds.height)) //  - rulerHeight
            context.strokePath()
            
            cursorColor.setFill()
            
            context.restoreGState()
        }
    }
    
    // MARK: - Helper Methods
    
    func setChannelHeight() {
        guard channelNames.count > 0 else { return  }
        
        let availableHeight = bounds.height // - rulerHeight
        let totalSpacing = CGFloat(channelWaveforms.count + 1) * channelSpacing
        let height = (availableHeight - totalSpacing) / CGFloat(channelWaveforms.count)
        channelHeight = max(minChannelHeight, min(height, maxChannelHeight))
        // let viewHeight = CGFloat(channelWaveforms.count) * channelHeight + totalSpacing
        updateContentSize()
        // return viewHeight
    }
    
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
        }
    }
    
    // MARK: - Public Methods
    
    /// Set custom channel names
    func setChannelNames(_ names: [Int: String], channelCount: Int) {
        channelNames = Array(repeating: "", count: channelCount)
        for (idx, _) in channelNames.enumerated() {
            if names[idx] != nil {
                channelNames[idx] = names[idx]!
            } else {
                channelNames[idx] = "Channel \(idx)"
            }
        }
        needsDisplay = true
    }
    
    /// Zoom in/out
    func setZoomLevel(_ pixelsPerSecond: CGFloat) {
        self.pixelsPerSecond = max(10, min(1000, pixelsPerSecond))
    }
    
    /// Get the total width needed for the waveform
    func getTotalWidth() -> CGFloat {
        return CGFloat(duration) * pixelsPerSecond // + channelLabelWidth
    }
        
    // MARK: - Mouse Interaction
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if location.x >= 0 {
            let clickedTime =  TimeInterval((location.x) / pixelsPerSecond) // - channelLabelWidth
            currentTime = max(0, min(duration, clickedTime))
            
            // Notify delegate or post notification for seeking
            NotificationCenter.default.post(
                name: NSNotification.Name("AudioWaveformViewDidSeek"),
                object: self,
                userInfo: ["time": currentTime]
            )
        }
    }
}


// MARK: - Scroll View Integration

extension AudioWaveformView {
    
    /// Update the intrinsic content size based on duration and zoom
    override var intrinsicContentSize: NSSize {
        let width = getTotalWidth()
        let channelCount = max(1, channelWaveforms.count)
        
        // Calculate height based on actual channel height
        let totalSpacing = CGFloat(channelCount + 1) * channelSpacing
        let calculatedHeight = CGFloat(channelCount) * channelHeight + totalSpacing
        
        return NSSize(width: width, height: calculatedHeight)
    }
    
    /// Call this when zoom changes to update the scroll view
    func updateContentSize() {
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }
    
    override var isFlipped: Bool {
        return true
    }
}


// MARK: - Waveform Caching

extension AudioWaveformView {
    
    /// Cache waveform data to avoid regeneration
    /// Note: NSCache automatically handles eviction, no manual cleanup needed
    private func cacheWaveform(_ key: String, waveforms: [[Float]]) {
        Self.waveformCache.setObject(WaveformCacheEntry(waveforms: waveforms), forKey: key as NSString)
    }
}
