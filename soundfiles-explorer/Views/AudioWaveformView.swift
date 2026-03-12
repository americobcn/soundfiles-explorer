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
            // Only update cursor layer for better performance
            updateCursorLayer()
        }
    }
    
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
    var backgroundColor: NSColor = NSColor.clear
    var waveformColors: [NSColor] = [
        NSColor(calibratedRed: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
        NSColor(calibratedRed: 1.0, green: 0.4, blue: 0.4, alpha: 1.0),
        NSColor(calibratedRed: 0.4, green: 1.0, blue: 0.6, alpha: 1.0),
        NSColor(calibratedRed: 0.6, green: 0.7, blue: 0.2, alpha: 1.0),
        NSColor(calibratedRed: 1.0, green: 0.5, blue: 0.7, alpha: 1.0),
        NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.1, alpha: 1.0),
        NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)
    ]
        
    var gridColor: NSColor = NSColor(calibratedWhite: 0.3, alpha: 0.5)
    var textColor: NSColor = .white
    
    /// Layout constants
    private let rulerHeight: CGFloat = 20
    private let channelSpacing: CGFloat = 1
    private let minChannelHeight: CGFloat = 60
    private let maxChannelHeight: CGFloat = 100
    private(set) var channelHeight: CGFloat = 60

    /// Zoom and scroll
    var pixelsPerSecond: CGFloat = 100 {
        didSet {
            needsDisplay = true
            updateSelectionLayers()
        }
    }
    
    // MARK: - Layers
    
    /// Layer for static waveform content (background + waveforms)
    private var waveformLayer: CALayer?
    
    /// Layer for playback cursor (updated frequently)
    private var cursorLayer: CALayer?
    
    /// Layer for ruler
    private var rulerLayer: CALayer?
    private var needsRulerUpdate = true

    // MARK: - Selection Layers
    private var leftDimLayer: CALayer?
    private var rightDimLayer: CALayer?
    private var selectionBorderLayer: CALayer?
    private var leftHandleLayer: CALayer?
    private var rightHandleLayer: CALayer?
    private var durationBadgeLayer: CATextLayer?

    /// Flag to track if waveform layer needs update
    private var needsWaveformUpdate = true

    /// Currently selected time region. Setting this updates all selection layers.
    private(set) var selectionRegion: (start: TimeInterval, end: TimeInterval)? {
        didSet { updateSelectionLayers() }
    }

            
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
                
    private func setupView() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.zPosition = 1
        
        // Create waveform layer for static content
        waveformLayer = CALayer()
        waveformLayer?.zPosition = 10
        // waveformLayer?.actions = ["position": NSNull(), "bounds": NSNull(), "frame": NSNull()]
        //waveformLayer?.borderColor = NSColor(calibratedWhite: 0.5, alpha: 1.0).cgColor
        waveformLayer?.borderWidth = 1.0
        
        layer?.addSublayer(waveformLayer!)
        
        // Create cursor layer for playback cursor
        cursorLayer = CALayer()
        cursorLayer?.zPosition = 50 // Ensure cursor is on top
        cursorLayer?.backgroundColor = NSColor.init(calibratedRed: 1.0, green: 0, blue: 0, alpha: 1).cgColor
                
        /// "position": NSNull() -> Prevent sync issues between cursorLayer, waveforms and what is heard.
        cursorLayer?.actions = [ "position": NSNull()] // , "position": NSNull(), "bounds": NSNull(), "frame": NSNull()
        layer?.addSublayer(cursorLayer!)
        
        // rulerLayer = CALayer()
        // rulerLayer?.zPosition = 100
        // rulerLayer?.backgroundColor = NSColor.darkGray.cgColor
        // layer?.addSublayer(rulerLayer!)

        // Left dim overlay (outside selection, left side)
        let leftDim = CALayer()
        leftDim.zPosition = 20
        leftDim.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.5).cgColor
        leftDim.isHidden = true
        layer?.addSublayer(leftDim)
        leftDimLayer = leftDim

        // Right dim overlay (outside selection, right side)
        let rightDim = CALayer()
        rightDim.zPosition = 21
        rightDim.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.5).cgColor
        rightDim.isHidden = true
        layer?.addSublayer(rightDim)
        rightDimLayer = rightDim

        // Selection border (white outline around selected region)
        let border = CALayer()
        border.zPosition = 22
        border.backgroundColor = NSColor.clear.cgColor
        border.borderColor = NSColor.white.withAlphaComponent(0.75).cgColor
        border.borderWidth = 1.5
        border.isHidden = true
        layer?.addSublayer(border)
        selectionBorderLayer = border

        // Left resize handle (pill grip on left edge)
        let lHandle = CALayer()
        lHandle.zPosition = 23
        lHandle.backgroundColor = NSColor.white.withAlphaComponent(0.85).cgColor
        lHandle.cornerRadius = 3
        lHandle.isHidden = true
        layer?.addSublayer(lHandle)
        leftHandleLayer = lHandle

        // Right resize handle (pill grip on right edge)
        let rHandle = CALayer()
        rHandle.zPosition = 24
        rHandle.backgroundColor = NSColor.white.withAlphaComponent(0.85).cgColor
        rHandle.cornerRadius = 3
        rHandle.isHidden = true
        layer?.addSublayer(rHandle)
        rightHandleLayer = rHandle

        // Duration badge (text label inside selection)
        // Note: CATextLayer.font expects CFTypeRef — cast explicitly to avoid runtime warning.
        let badge = CATextLayer()
        badge.zPosition = 25
        badge.fontSize = 10
        badge.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium) as CFTypeRef
        badge.foregroundColor = NSColor.white.cgColor
        badge.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.12).cgColor
        badge.cornerRadius = 3
        badge.alignmentMode = .center
        badge.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        badge.isHidden = true
        layer?.addSublayer(badge)
        durationBadgeLayer = badge

        // Disable implicit animations on all selection layers
        let noAnimation: [String: CAAction] = ["position": NSNull(), "bounds": NSNull(), "frame": NSNull(),
                           "hidden": NSNull(), "backgroundColor": NSNull()]
        leftDim.actions = noAnimation
        rightDim.actions = noAnimation
        border.actions = noAnimation
        lHandle.actions = noAnimation
        rHandle.actions = noAnimation
        // Badge also suppresses "string" to prevent cross-fade flicker during live drag updates
        badge.actions = ["position": NSNull(), "bounds": NSNull(), "frame": NSNull(),
                         "hidden": NSNull(), "backgroundColor": NSNull(), "string": NSNull()]
    }
    
    
    // MARK: - Audio Loading
    
    /// Sets waveform data directly from pre-loaded audio file
    /// - Parameters:
    ///   - waveformData: The pre-generated waveform data for each channel
    ///   - duration: The duration of the audio file in seconds
    ///   - sampleRate: The sample rate of the audio file
    ///   - channelCount: The number of audio channels
    func setWaveformData(_ waveformData: [[Float]], duration: TimeInterval, sampleRate: Double, channelCount: Int, names: [Int: String]) {
        selectionRegion = nil
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
        
        // Invalidate waveform layer to force re-render
        invalidateWaveformLayer()
        updateContentSize()
    }
    
    /// Shows loading state when waveform data is not yet available
    func showLoadingState(duration: TimeInterval, sampleRate: Double, channelCount: Int, names: [Int: String]) {
        selectionRegion = nil
        self.channelWaveforms = []
        self.duration = duration
        self.sampleRate = sampleRate
        
        channelNames = Array(repeating: "", count: channelCount)
        for idx in 0..<channelCount {
            if names[idx + 1] != nil && names[idx + 1]?.isEmpty == false {
                channelNames[idx] = "\(names[idx + 1]!)\nCh \(idx + 1)"
            } else {
                channelNames[idx] = "Ch \(idx + 1)"
            }
        }
        
        // Invalidate waveform layer to show loading state
        invalidateWaveformLayer()
        updateContentSize()
    }
    
    /// Clears the waveform view completely
    func clearWaveform() {
        selectionRegion = nil
        self.channelWaveforms = []
        self.duration = 0
        self.sampleRate = 0
        self.channelNames = []
        
        // Clear layers
        waveformLayer?.contents = nil
        cursorLayer?.contents = nil
        
        invalidateWaveformLayer()
        updateContentSize()
    }

    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Always ensure waveformLayer frame is correct for scrolling
        if let waveformLayer = waveformLayer {
            let fullContentWidth = getTotalWidth()
            let fullContentHeight = intrinsicContentSize.height
            waveformLayer.frame = NSRect(x: 0, y: 0, width: fullContentWidth, height: max(fullContentHeight, bounds.height))
        }
        
        // Render waveform layer if needed
        if needsWaveformUpdate {
            renderWaveformLayer()            
        }
        
        // drawTimeRuler()
        
        // Update cursor layer (always update on draw)
        updateCursorLayer()
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
    
    private func drawLoadingState(in context: CGContext, fullBounds: NSRect) {
        let message = "Loading waveforms..."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]
        
        let attributedString = NSAttributedString(string: message, attributes: attributes)
        let size = attributedString.size()
        let point = NSPoint(
            x: (fullBounds.width - size.width) / 2,
            y: (fullBounds.height - size.height) / 2
        )
        
        attributedString.draw(at: point)
        
        // Draw placeholder channel backgrounds
        let channelCount = max(1, channelNames.count)
        let totalSpacing = CGFloat(channelCount + 1) * channelSpacing
        let calculatedHeight = CGFloat(channelCount) * channelHeight + totalSpacing
        let startY = max(0, (fullBounds.height - calculatedHeight) / 2)
        
        for idx in 0..<channelCount {
            let yPosition = startY + channelSpacing + CGFloat(idx) * (channelHeight + channelSpacing)
            let channelRect = NSRect(x: 0, y: yPosition, width: fullBounds.width, height: channelHeight)
            
            // Draw subtle placeholder background
            let c = NSColor(calibratedWhite: 0.7, alpha: 0.03)
            context.setFillColor(c.cgColor)
            context.fill(channelRect)
        }
    }
    
    private func drawTimeRuler() {
        guard waveformLayer != nil else { return }
        
        // Get full content dimensions for scrolling
        let fullContentWidth = getTotalWidth()
        let rulerRect = NSRect(x: 0, y: (layer?.frame.height)!, width: fullContentWidth , height: rulerHeight) //
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: Int(fullContentWidth),
            height: Int(rulerHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return }
        
        
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
        
        let startTime = 0.0
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
        
        needsRulerUpdate = true
    }
    
        
    private func drawWaveform(_ waveform: [Float], in rect: NSRect, color: NSColor, context: CGContext) {
        guard !waveform.isEmpty else { return }
        
        let midY = rect.midY
        let maxAmplitude = rect.height / 2 - 1
        
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
        context.restoreGState()
    }

    
    // MARK: - Layer Rendering
    
    /// Renders static waveform content to waveformLayer
    private func renderWaveformLayer() {
        guard let waveformLayer = waveformLayer else { return }
        
        // Get full content dimensions for scrolling
        let fullContentWidth = getTotalWidth()
        let fullContentHeight = intrinsicContentSize.height
        
        // Update layer frame to cover full scrollable content
        waveformLayer.frame = NSRect(x: 0, y: 0, width: fullContentWidth, height: max(fullContentHeight, bounds.height))
        waveformLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 1.0
        
        // Create bitmap context for rendering full content width
        let width = Int(fullContentWidth)
        let height = Int(max(fullContentHeight, bounds.height))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
                        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return }
        
        // Flip context to match flipped view coordinate system (0,0 at top-left)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        
        // Draw background for full content area
        let fullBounds = NSRect(x: 0, y: 0, width: fullContentWidth, height: CGFloat(height))
        context.setFillColor(NSColor.clear.cgColor)
        context.fill(fullBounds) //fullBounds
        
        // Draw channels
        let channelCount = channelWaveforms.count
        guard channelCount > 0 else {
            // If duration > 0 but no waveforms, we're in loading state
            if duration > 0 {
                drawLoadingState(in: context, fullBounds: fullBounds)
            }
            // Set rendered image to layer
            if let cgImage = context.makeImage() {
                waveformLayer.contents = cgImage
            }
            return
        }
        
        // Calculate starting Y to attach channels to top when content fits
        let startY = max(0, CGFloat(height) - fullContentHeight)
        
        // Draw each channel across full width
        for (index, waveform) in channelWaveforms.enumerated() {
            let yPosition = startY  + CGFloat(index) * (channelHeight + channelSpacing)
            let channelRect = NSRect(x: 0, y: yPosition, width: fullContentWidth, height: channelHeight)
            
            // Draw channel background
            let c = NSColor(calibratedWhite: 0.7, alpha: 0.075)
            context.setFillColor(c.cgColor)
            context.fill(channelRect)
            
            // Draw waveform
            let color = waveformColors[index % waveformColors.count]
            drawWaveform(waveform, in: channelRect, color: color, context: context)
                        
        }
        
        // Set rendered image to layer
        if let cgImage = context.makeImage() {
            waveformLayer.contents = cgImage
        }
        
        needsWaveformUpdate = true
    }
    
    /// Updates all selection layer frames and visibility. Called whenever selectionRegion changes.
    /// Never re-renders the waveform bitmap — only repositions layers.
    private func updateSelectionLayers() {
        let hidden = selectionRegion == nil
        leftDimLayer?.isHidden = hidden
        rightDimLayer?.isHidden = hidden
        selectionBorderLayer?.isHidden = hidden
        leftHandleLayer?.isHidden = hidden
        rightHandleLayer?.isHidden = hidden
        durationBadgeLayer?.isHidden = hidden

        guard let region = selectionRegion else { return }

        let h = bounds.height
        let leftX  = CGFloat(region.start) * pixelsPerSecond
        let rightX = CGFloat(region.end)   * pixelsPerSecond

        // Left dim: from 0 to selection start
        leftDimLayer?.frame  = CGRect(x: 0,      y: 0, width: leftX,              height: h)
        // Right dim: from selection end to full content width
        let totalWidth = getTotalWidth()
        rightDimLayer?.frame = CGRect(x: rightX, y: 0, width: max(0, totalWidth - rightX), height: h)
        // Border: exactly over the selection
        selectionBorderLayer?.frame = CGRect(x: leftX, y: 0, width: rightX - leftX, height: h)

        // Handles: pill shape, vertically centred on each edge
        let handleW: CGFloat = 9
        let handleH: CGFloat = 20
        let handleY = (h - handleH) / 2
        leftHandleLayer?.frame  = CGRect(x: leftX  - handleW / 2, y: handleY, width: handleW, height: handleH)
        rightHandleLayer?.frame = CGRect(x: rightX - handleW / 2, y: handleY, width: handleW, height: handleH)

        // Duration badge: centred inside selection, near top
        let regionDuration = region.end - region.start
        let durationText = formatTime(regionDuration)
        let badgeW: CGFloat = 60
        let badgeH: CGFloat = 16
        let badgeCenterX = leftX + (rightX - leftX) / 2
        durationBadgeLayer?.string = durationText
        durationBadgeLayer?.frame = CGRect(
            x: badgeCenterX - badgeW / 2,
            y: 4,
            width: badgeW,
            height: badgeH
        )

        // Post selection-changed notification
        NotificationCenter.default.post(
            name: NSNotification.Name("AudioWaveformViewSelectionChanged"),
            object: self,
            userInfo: ["start": region.start, "end": region.end]
        )
    }

    /// Updates cursor layer with current playback position
    private func updateCursorLayer() {
        guard let cursorLayer = cursorLayer else { return }
        guard duration > 0 else {
            cursorLayer.contents = nil
            return
        }
        
        cursorLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 1.0
        let x = CGFloat(currentTime) * pixelsPerSecond
        
        // Only draw if cursor is visible
        if x >= 0 && x <= bounds.width {
            // Position cursor layer at cursor location
            cursorLayer.frame = NSRect(x: x, y: 0, width: 2.0, height: bounds.height)
        }
    }
        
    /// Invalidates waveform layer to force re-render
    func invalidateWaveformLayer() {
        needsWaveformUpdate = true
        needsDisplay = true
    }
    
    
    // MARK: - Helper Methods
    
    func setChannelHeight() {
        guard channelNames.count > 0 else { return  }
        let availableHeight = bounds.height // - rulerHeight
        let totalSpacing = CGFloat(channelWaveforms.count + 1) * channelSpacing
        let height = (availableHeight - totalSpacing) / CGFloat(channelWaveforms.count)
        channelHeight = max(minChannelHeight, min(height, maxChannelHeight))
        updateContentSize()
        
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
        self.pixelsPerSecond = pixelsPerSecond // max(10, min(1000, pixelsPerSecond))
        // Invalidate waveform layer to force re-render with new zoom level
        invalidateWaveformLayer()
    }
    
    /// Get the total width needed for the waveform
    func getTotalWidth() -> CGFloat {
        return CGFloat(duration) * pixelsPerSecond
    }
        
    // MARK: - Mouse Interaction
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if location.x >= 0 {
            let clickedTime =  TimeInterval((location.x) / pixelsPerSecond)
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









/*************************************************/
/**     UNUSED                                  **/
/*************************************************/
/*
 private func drawChannelLabel(_ label: String, at point: NSPoint, in context: CGContext) {
     let attributes: [NSAttributedString.Key: Any] = [
         .font: NSFont.systemFont(ofSize: 11, weight: .medium),
         .foregroundColor: textColor
     ]
     
     let attributedString = NSAttributedString(string: label, attributes: attributes)
     let size = attributedString.size()
     attributedString.draw(at: NSPoint(x: point.x  , y: point.y - size.height / 2))
 }
 
 
 
 
*/
