# AGENTS.md

Guidelines for agentic coding agents working in this macOS audio file explorer.

## Project Overview

macOS audio file explorer with Swift and AppKit. Parses BEXT/iXML metadata from WAV files, displays multi-channel waveforms with playback.

**Key Constraint**: No SwiftUI or Storyboards. Pure AppKit/NSView.

## Build Commands

```bash
# Build
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Release
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Debug

# Run
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Debug && open build/Debug/soundfiles-explorer.app

# Clean
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer clean

# Test
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -only-testing:soundfiles-explorerTests/MyTestClass
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -only-testing:soundfiles-explorerTests/MyTestClass/testMethodName
```

**Note**: Xcode project (not SPM). No `swift build`.

## Testing

**Current Status**: No unit test target configured.

Add tests via: File → New → Target → Unit Testing Bundle

```bash
# Run all tests
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer

# Run single test class
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -only-testing:soundfiles-explorerTests/MyTestClass

# Run single test method
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -only-testing:soundfiles-explorerTests/MyTestClass/testMethodName
```

**Manual Testing**: Drag WAV files with BEXT/iXML, use Space/K (play/pause), J/L (seek), click waveform to seek.

## Code Style

### Formatting
- 4 spaces, no tabs
- Braces on same line
- Single blank line between methods, after MARK comments
- Line length: soft limit 120 chars, hard limit 160 chars

### File Organization
```swift
//
//  FileName.swift
//  soundfiles-explorer
//

import Cocoa
import AVFoundation
import Foundation

// MARK: - Types/Protocols
// MARK: - Main Class/Struct
// MARK: - Private Extensions
// MARK: - Public Methods
// MARK: - Private Methods
```

### Naming
- Types: PascalCase (`AudioMetadataReader`)
- Variables: camelCase (`currentTime`)
- Constants: camelCase local, UPPER_SNAKE global (`maxCacheSize`)
- Methods: camelCase verb prefix (`loadAudioFile()`)
- Protocols: PascalCase descriptor suffix (`AudioParserDelegate`)
- Enums: PascalCase, lowercase cases (`case invalidFile`)
- Private: No underscore prefix, use `private` modifier
- Boolean: start with `is` (`isPlaying`)

### Types
- Prefer `let`, use `Int`, `Double`, `Float` (not `CGFloat` unless UI)
- Use `TimeInterval` for time values
- Explicit types for public APIs
- Use `Result` for async operations

### Error Handling
```swift
enum AudioParserError: Error, LocalizedError {
    case invalidFile
    case noAudioTrack
    var errorDescription: String? {
        switch self {
        case .invalidFile: return "File is too small or corrupted."
        case .noAudioTrack: return "No audio track found."
        }
    }
}
guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
    throw AudioParserError.noAudioTrack
}
```

### Access Control
- Default `private` for implementation
- `internal` (default) for module APIs
- `public` only for framework exports
- `final` on classes unless inheritance needed

### Imports
- Apple frameworks first, then third-party, then project
- Only import what you use
- Common: `Foundation`, `Cocoa`, `AVFoundation`, `AVKit`, `CoreMedia`

### Comments
- `//` for single-line, `/* */` for disabling blocks
- `// MARK: - Section` for organization
- `///` for public API docs
- Avoid obvious comments

### Architecture
- MVC pattern throughout
- NSView subclasses for custom UI
- NotificationCenter for loose coupling
- Async/await for async operations

### Auto Layout
- `NSLayoutConstraint.activate([...])` for batch activation
- `translatesAutoresizingMaskIntoConstraints = false` for programmatic UI

### Swift Concurrency
- Use `MainActor` for UI updates
- Use `async/await` for async operations
- Wrap UI updates with `await MainActor.run { ... }`

## Key Files
- `MVC.swift`: Main view controller (MVC pattern)
- `AudioMetadataReader.swift`: BEXT/iXML WAV metadata parsing
- `AudioWaveformView.swift`: Multi-channel waveform visualization with CALayers
- `AudioPlaybackManager.swift`: AVAudioPlayer wrapper for playback control
- `AudioFileLoader.swift`: File loading, waveform generation, and caching
- `AudioParserError.swift`: Custom error types with LocalizedError conformance

## Swift Version & Deployment
- Swift 5.0+ with Swift Concurrency (async/await)
- Deployment target: macOS 14.6+ (Xcode 26.2)
- Main actor isolation for UI updates

## Frameworks
- AppKit (NSView, NSWindow, CALayer, etc.)
- AVFoundation (AVAudioFile, AVPlayerItem, AVURLAsset, CMTime)
- CoreMedia (CMTime, AudioStreamBasicDescription)
- No external dependencies

## Audio Support
- WAV (recommended, BEXT/iXML)
- AIFF, CAF, MP3, M4A (basic)

## Keyboard Shortcuts
- Space/K: Play/Pause
- J: Rewind
- L: Fast forward
- Delete: Remove selected rows
- Arrow keys: Navigate waveform (Shift/Cmd modifiers)

## Common Patterns

### Notification Usage
```swift
NotificationCenter.default.post(
    name: NSNotification.Name("AudioWaveformViewDidSeek"),
    object: self,
    userInfo: ["time": currentTime]
)
NotificationCenter.default.addObserver(
    self,
    selector: #selector(waveformViewDidSeek(_:)),
    name: NSNotification.Name("AudioWaveformViewDidSeek"),
    object: waveformView
)
```

### CADisplayLink for Animation
```swift
displayLink = self.waveformView.displayLink(target: self, selector: #selector(updatePlaybackPosition))
displayLink?.isPaused = true
displayLink?.add(to: .main, forMode: .common)
```

### Time Formatting
```swift
private func formatTime(_ time: TimeInterval) -> String {
    guard time >= 0 else { return "--" }
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
    return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
}
```

