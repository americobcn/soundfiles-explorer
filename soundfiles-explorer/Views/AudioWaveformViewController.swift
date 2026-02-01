import Cocoa
import AVFoundation

protocol AudioWaveformViewControllerDelegate {
    func audioURLDidChange(_ url: URL)
}

/// Example view controller showing how to use AudioWaveformView
class AudioWaveformViewController: NSViewController {
    // MARK: - UI Components
    
    private var scrollView: NSScrollView!
    private var waveformView: AudioWaveformView!
    private var controlsStackView: NSStackView!
    private var playPauseButton: NSButton!
    private var zoomSlider: NSSlider!
    private var timeLabel: NSTextField!
    
    // MARK: - Audio Playback
    
    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CVDisplayLink?
    private var audioURL: URL?
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1522, height: 208))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDisplayLink()
        setupNotifications()
        
    }
    
    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        print("AudioWaveFormController call: setupUI()")
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        
        // Create scroll view
        // scrollView = NSScrollView(frame: view.bounds)
        // scrollView.autoresizingMask = [.width, .height]
        // scrollView.hasHorizontalScroller = true
        // scrollView.hasVerticalScroller = true
        // scrollView.autohidesScrollers = false
        // scrollView.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 1.0)
        
        // Create waveform view
        print("AudioWaveformViewController waveformView before: \(String(describing: waveformView))")
        waveformView = AudioWaveformView(frame: view.bounds)
        guard waveformView != nil else {
            print("waveformView: \(String(describing: waveformView))")
            return
        }
        print("AudioWaveformViewController waveformView after: \(String(describing: waveformView))")
        print("AudioWaveformViewController waveformView.audioURL after: \(String(describing: waveformView.audioURL))")
        
        // Set up scroll view
        // scrollView.documentView = waveformView
        // self.view = waveformView
        
        // Create controls
        // setupControls()
        
        // Layout
        // let mainStack = NSStackView(views: [scrollView])
        // mainStack.orientation = .vertical
        // mainStack.spacing = 0
        // mainStack.translatesAutoresizingMaskIntoConstraints = false
        //
        self.view.addSubview(waveformView)
        // //
        // NSLayoutConstraint.activate([
        //     mainStack.topAnchor.constraint(equalTo: view.topAnchor),
        //     mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        //     mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        //     mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        //     // controlsStackView.heightAnchor.constraint(equalToConstant: 60)
        // ])
    }
    
    private func setupControls() {
        // Play/Pause button
        playPauseButton = NSButton(title: "▶ Play", target: self, action: #selector(playPauseAction))
        playPauseButton.bezelStyle = .rounded
        playPauseButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        // Open file button
        let openButton = NSButton(title: "Open Audio File", target: self, action: #selector(openFileAction))
        openButton.bezelStyle = .rounded
        
        // Zoom label
        let zoomLabel = NSTextField(labelWithString: "Zoom:")
        
        // Zoom slider
        zoomSlider = NSSlider(value: 100, minValue: 10, maxValue: 500, target: self, action: #selector(zoomChanged))
        zoomSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        
        // Time label
        timeLabel = NSTextField(labelWithString: "0:00.00 / 0:00.00")
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = .white
        timeLabel.widthAnchor.constraint(equalToConstant: 150).isActive = true
        
        // Create stack view for controls
        controlsStackView = NSStackView(views: [
            playPauseButton,
            openButton,
            NSView(), // Spacer
            zoomLabel,
            zoomSlider,
            timeLabel
        ])
        controlsStackView.orientation = .horizontal
        controlsStackView.spacing = 10
        controlsStackView.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        controlsStackView.wantsLayer = true
        controlsStackView.layer?.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 1.0).cgColor
        
        // Make the spacer view expand
        let spacer = controlsStackView.arrangedSubviews[2]
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(waveformViewDidSeek(_:)),
            name: NSNotification.Name("AudioWaveformViewDidSeek"),
            object: waveformView
        )
    }
    
    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
                let controller = Unmanaged<AudioWaveformViewController>.fromOpaque(displayLinkContext!).takeUnretainedValue()
                controller.updatePlaybackPosition()
                return kCVReturnSuccess
            }, Unmanaged.passUnretained(self).toOpaque())
            
            CVDisplayLinkStart(displayLink)
        }
    }
    
    // MARK: - Actions    
    @objc private func openFileAction() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadAudioFile(url)
        }
    }
    
    @objc private func playPauseAction() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            playPauseButton.title = "▶ Play"
            waveformView.isPlaying = false
        } else {
            player.play()
            playPauseButton.title = "⏸ Pause"
            waveformView.isPlaying = true
        }
    }
    
    @objc private func zoomChanged() {
        waveformView.setZoomLevel(CGFloat(zoomSlider.doubleValue))
        waveformView.updateContentSize()
    }
    
    @objc private func waveformViewDidSeek(_ notification: Notification) {
        guard let time = notification.userInfo?["time"] as? TimeInterval,
              let player = audioPlayer else { return }
        
        player.currentTime = time
        waveformView.currentTime = time
    }
    
    // MARK: - Audio Loading
    
    func loadAudioFile(_ url: URL) {
        audioURL = url
        
        waveformView = AudioWaveformView(frame: view.bounds)
        view.addSubview(waveformView)
        waveformView.audioURL = url
        
        
        // Setup audio player
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1.0
            
            // updateTimeLabel()
            
            // You can customize channel names based on your audio file
            // For example, if you know the file has specific channels:
            // waveformView.setChannelNames(["Boom Mic", "Lav 1", "Lav 2", "Ambient"])
            
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error Loading Audio"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
        view.needsDisplay = true
    }
    
    // MARK: - Playback Updates
    
    private func updatePlaybackPosition() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let player = self.audioPlayer else { return }
            
            self.waveformView.currentTime = player.currentTime
            // self.updateTimeLabel()
            
            // Auto-scroll to follow playback
            if player.isPlaying {
                self.scrollToFollowPlayback()
            }
        }
    }
    
    private func updateTimeLabel() {
        guard let player = audioPlayer else {
            timeLabel.stringValue = "0:00.00 / 0:00.00"
            return
        }
        
        let current = formatTime(player.currentTime)
        let total = formatTime(player.duration)
        timeLabel.stringValue = "\(current) / \(total)"
    }
    
    private func scrollToFollowPlayback() {
        guard let player = audioPlayer else { return }
        
        let visibleRect = scrollView.documentVisibleRect
        let cursorX = 120 + CGFloat(player.currentTime) * waveformView.pixelsPerSecond
        
        // Scroll if cursor is near the edges or outside visible area
        let scrollMargin: CGFloat = 100
        let needsScroll = cursorX < visibleRect.minX + scrollMargin ||
                         cursorX > visibleRect.maxX - scrollMargin
        
        if needsScroll {
            let newX = max(0, cursorX - visibleRect.width / 2)
            scrollView.contentView.scroll(to: NSPoint(x: newX, y: visibleRect.minY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

// MARK: - Window Controller

class AudioWaveformWindowController: NSWindowController {
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Audio Waveform Viewer"
        window.contentViewController = AudioWaveformViewController()
        window.center()
        
        self.init(window: window)
    }
}
