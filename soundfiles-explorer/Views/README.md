# AudioWaveformView - Multi-Channel Audio Waveform Display for macOS

A complete, production-ready NSView replacement for AVPlayerView that displays multi-channel audio waveforms with playback cursor, time ruler, and extensive customization options.

## Features

- ✅ **Multi-channel support**: Display up to 4+ audio channels simultaneously (Boom mic, wireless mics, etc.)
- ✅ **Playback cursor**: Visual indicator that follows the current playback position
- ✅ **Time ruler**: Precise time markers with automatic scaling based on zoom level
- ✅ **Zoom and scroll**: Adjustable pixels-per-second zoom with smooth scrolling
- ✅ **Click-to-seek**: Click anywhere on the waveform to jump to that time
- ✅ **Customizable colors**: Individual colors for each channel, cursor, grid, and background
- ✅ **Auto-scroll**: Automatically follows playback when enabled
- ✅ **Performance optimized**: Efficient waveform generation and rendering

## Installation

Simply add `AudioWaveformView.swift` and `AudioWaveformViewController.swift` to your Xcode project.

## Basic Usage

### 1. Using with Storyboard/XIB

```swift
// In your view controller
@IBOutlet weak var waveformView: AudioWaveformView!

override func viewDidLoad() {
    super.viewDidLoad()
    
    // Load audio file
    if let url = Bundle.main.url(forResource: "audio", withExtension: "wav") {
        waveformView.audioURL = url
    }
    
    // Customize appearance
    waveformView.waveformColors = [
        .systemBlue,
        .systemRed,
        .systemGreen,
        .systemYellow
    ]
}
```

### 2. Programmatic Usage

```swift
// Create waveform view
let waveformView = AudioWaveformView(frame: .zero)
waveformView.translatesAutoresizingMaskIntoConstraints = false

// Add to scroll view
let scrollView = NSScrollView()
scrollView.documentView = waveformView

// Load audio
waveformView.audioURL = audioFileURL

// Update playback position (call this in your display link or timer)
waveformView.currentTime = audioPlayer.currentTime
```

### 3. Integration with AVAudioPlayer

```swift
class MyViewController: NSViewController {
    var audioPlayer: AVAudioPlayer?
    var waveformView: AudioWaveformView!
    var displayLink: CVDisplayLink?
    
    func loadAudio(url: URL) {
        // Setup player
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        
        // Setup waveform
        waveformView.audioURL = url
        
        // Start display link for smooth updates
        setupDisplayLink()
    }
    
    func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, { (_, _, _, _, _, context) -> CVReturn in
                let controller = Unmanaged<MyViewController>.fromOpaque(context!).takeUnretainedValue()
                DispatchQueue.main.async {
                    controller.waveformView.currentTime = controller.audioPlayer?.currentTime ?? 0
                }
                return kCVReturnSuccess
            }, Unmanaged.passUnretained(self).toOpaque())
            
            CVDisplayLinkStart(displayLink)
        }
    }
}
```

## Customization

### Channel Names

```swift
waveformView.setChannelNames([
    "Boom Microphone",
    "Wireless Mic 1",
    "Wireless Mic 2",
    "Wireless Mic 3"
])
```

### Colors

```swift
// Background
waveformView.backgroundColor = NSColor(white: 0.15, alpha: 1.0)

// Waveform colors (one per channel)
waveformView.waveformColors = [
    NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.8),  // Blue
    NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 0.8),  // Red
    NSColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 0.8),  // Green
    NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.8)   // Yellow
]

// Cursor color
waveformView.cursorColor = .systemRed

// Grid and text
waveformView.gridColor = NSColor(white: 0.3, alpha: 0.5)
waveformView.textColor = .white
```

### Zoom Level

```swift
// Set pixels per second (10-1000)
waveformView.setZoomLevel(200) // 200 pixels per second

// Get total width needed
let totalWidth = waveformView.getTotalWidth()
```

## Seeking

The view automatically posts a notification when the user clicks to seek:

```swift
// Listen for seek events
NotificationCenter.default.addObserver(
    self,
    selector: #selector(didSeek(_:)),
    name: NSNotification.Name("AudioWaveformViewDidSeek"),
    object: waveformView
)

@objc func didSeek(_ notification: Notification) {
    if let time = notification.userInfo?["time"] as? TimeInterval {
        audioPlayer?.currentTime = time
    }
}
```

## Complete Example

See `AudioWaveformViewController.swift` for a complete, working example that includes:

- File opening dialog
- Play/pause controls
- Zoom slider
- Time display
- Auto-scrolling
- Seek functionality

## Advanced Features

### Custom Waveform Generation

The waveform is automatically generated when you set the `audioURL` property. The generation process:

1. Reads the audio file using AVAudioFile
2. Processes samples in chunks for memory efficiency
3. Calculates peak values for each point
4. Stores separate waveform data for each channel

### Performance Considerations

- **Large files**: The view handles large audio files efficiently by downsampling
- **Real-time updates**: Use CVDisplayLink for smooth 60fps cursor updates
- **Memory**: Waveform data is stored as Float arrays, minimizing memory usage

### Scroll View Integration

The view is designed to work seamlessly with NSScrollView:

```swift
let scrollView = NSScrollView()
scrollView.hasHorizontalScroller = true
scrollView.hasVerticalScroller = true
scrollView.documentView = waveformView

// The view will automatically calculate its intrinsic content size
waveformView.updateContentSize()
```

## Supported Audio Formats

The view supports any audio format that AVAudioFile can read:

- WAV (recommended for multi-channel)
- AIFF
- CAF
- MP3
- M4A
- And more...

## API Reference

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `audioURL` | `URL?` | The audio file to display |
| `currentTime` | `TimeInterval` | Current playback position |
| `isPlaying` | `Bool` | Playback state indicator |
| `pixelsPerSecond` | `CGFloat` | Zoom level (10-1000) |
| `backgroundColor` | `NSColor` | Background color |
| `waveformColors` | `[NSColor]` | Colors for each channel |
| `cursorColor` | `NSColor` | Playback cursor color |
| `gridColor` | `NSColor` | Grid and ruler color |
| `textColor` | `NSColor` | Text label color |

### Methods

| Method | Description |
|--------|-------------|
| `setChannelNames(_ names: [String])` | Set custom channel labels |
| `setZoomLevel(_ pixelsPerSecond: CGFloat)` | Change zoom level |
| `getTotalWidth() -> CGFloat` | Get total width for scrolling |
| `updateContentSize()` | Update intrinsic size after changes |

### Notifications

| Name | UserInfo | Description |
|------|----------|-------------|
| `AudioWaveformViewDidSeek` | `["time": TimeInterval]` | Posted when user clicks to seek |

## Requirements

- macOS 10.15+
- Swift 5.0+
- AVFoundation framework

## Tips & Tricks

### Auto-scrolling During Playback

```swift
func scrollToFollowPlayback() {
    let visibleRect = scrollView.documentVisibleRect
    let cursorX = 120 + CGFloat(audioPlayer.currentTime) * waveformView.pixelsPerSecond
    
    if cursorX > visibleRect.maxX - 100 {
        let newX = cursorX - visibleRect.width / 2
        scrollView.contentView.scroll(to: NSPoint(x: newX, y: 0))
    }
}
```

### Exporting Waveform as Image

```swift
func exportWaveformImage() -> NSImage? {
    guard let bitmap = waveformView.bitmapImageRepForCachingDisplay(in: waveformView.bounds) else {
        return nil
    }
    
    waveformView.cacheDisplay(in: waveformView.bounds, to: bitmap)
    
    let image = NSImage(size: waveformView.bounds.size)
    image.addRepresentation(bitmap)
    return image
}
```

### Handling Different Channel Counts

The view automatically adapts to any number of channels:

```swift
// 1 channel (mono)
// 2 channels (stereo)
// 4 channels (boom + 3 wireless)
// 8+ channels (multitrack recording)

// The view will adjust channel height automatically
// and use colors from the waveformColors array, cycling if needed
```

## License

Free to use in your projects. No attribution required.

## Credits

Created as a professional replacement for AVPlayerView with enhanced audio visualization capabilities.
