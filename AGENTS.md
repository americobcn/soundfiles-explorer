# AGENTS.md

Guidelines for agentic coding agents working on this macOS audio file explorer application.

## Project Overview

macOS audio file explorer built with Swift and AppKit. Parses BEXT/iXML metadata from WAV files and displays multi-channel waveforms with playback.

**Key Constraint**: No SwiftUI or Storyboards. Pure AppKit/NSView implementation.

## Build Commands

```bash
# Build (Release)
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Release

# Build (Debug)
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Debug

# Build and run
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Debug && open build/Debug/soundfiles-explorer.app

# Clean build
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer clean
```

**Note**: Xcode project (not SPM). No `swift build` available.

## Testing

**Current Status**: No unit test target configured.

To add tests: File → New → Target → Unit Testing Bundle, then run:
```bash
# Run all tests
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer

# Run single test class
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -only-testing:soundfiles-explorerTests/MyTestClass

# Run single test method
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -only-testing:soundfiles-explorerTests/MyTestClass/testMethodName
```

**Manual Testing**: Drag WAV files with BEXT/iXML chunks, use Space/K (play/pause), J/L (seek), click waveform to seek.

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
//  Created by [Name] on [Date].
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

### Naming Conventions
- Types: PascalCase (`AudioMetadataReader`, `BEXTMetadata`)
- Variables: camelCase (`currentTime`, `sampleRate`)
- Constants: camelCase for local, UPPER_SNAKE for global (`maxCacheSize`)
- Methods: camelCase verb prefix (`loadAudioFile()`, `generateWaveforms()`)
- Protocols: PascalCase descriptor suffix (`AudioParserDelegate`)
- Enums: PascalCase, lowercase cases (`case invalidFile`)
- Private: No underscore prefix, use `private` modifier
- Boolean properties: start with `is` (`isPlaying`, `isSeeking`)

### Types
- Prefer `let` over `var`
- Use `Int`, `Double`, `Float` (not `CGFloat` unless UI-related)
- Use `TimeInterval` for time values
- Explicit types for public APIs, inference allowed for local variables
- Use `Result` type for async operations with multiple outcomes

### Error Handling
```swift
enum AudioParserError: Error, LocalizedError {
    case invalidFile
    case noAudioTrack
    
    var errorDescription: String? {
        switch self {
        case .invalidFile: return "File is too small or corrupted."
        case .noAudioTrack: return "No audio track found in the asset."
        }
    }
}

guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
    throw AudioParserError.noAudioTrack
}
```

### Access Control
- Default to `private` for implementation details
- Use `internal` (default) for module-internal APIs
- Use `public` only for framework-exported APIs
- Use `final` on classes unless inheritance is needed

### Imports
- Group by: Apple frameworks first, then third-party, then project modules
- Only import what you use
- Common: `Foundation`, `Cocoa`, `AVFoundation`, `AVKit`, `CoreMedia`

### Comments
- `//` for single-line comments
- `/* */` only for temporarily disabling code blocks
- `// MARK: - Section Name` for file organization
- `///` for public API documentation
- Avoid obvious comments (e.g., `// increment i`)

### Architecture Patterns
- MVC pattern throughout
- NSView subclasses for custom UI (no SwiftUI)
- NotificationCenter for loose coupling between components
- Async/await for asynchronous operations
- Private nested classes for file-local types

### Auto Layout
- `NSLayoutConstraint.activate([...])` for batch activation
- `translatesAutoresizingMaskIntoConstraints = false` for programmatic UI
- Use Auto Layout, not autoresizing masks (except for documentView edge cases)

## Key Files
- `MVC.swift`: Main view controller, handles table view and player integration
- `AudioMetadataReader.swift`: BEXT/iXML metadata parsing from WAV chunks
- `AudioWaveformView.swift`: Custom NSView for waveform visualization
- `AudioPlaybackManager.swift`: AVPlayer wrapper for audio playback control
- `AudioParserError.swift`: Error definitions for audio parsing

## Frameworks
- AppKit (NSView, NSWindow, NSButton, etc.)
- AVFoundation (audio playback, metadata extraction)
- CoreMedia (CMTime calculations)
- No external dependencies (pure Apple frameworks)

## Audio Support
- WAV (recommended, supports BEXT/iXML metadata)
- AIFF, CAF, MP3, M4A (basic support)

## Keyboard Shortcuts
- Space/K: Play/Pause
- J: Rewind (scrub backward)
- L: Fast forward (scrub forward)
- Delete: Remove selected rows
- Arrow keys: Navigate waveform (with Shift/Cmd modifiers)

## Common Patterns

### Notification Usage
```swift
// Post notification
NotificationCenter.default.post(
    name: NSNotification.Name("AudioWaveformViewDidSeek"),
    object: self,
    userInfo: ["time": currentTime]
)

// Observe notification
NotificationCenter.default.addObserver(
    self,
    selector: #selector(waveformViewDidSeek(_:)),
    name: NSNotification.Name("AudioWaveformViewDidSeek"),
    object: waveformView
)
```

### CVDisplayLink for Animation
```swift
CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
if let displayLink = displayLink {
    CVDisplayLinkSetOutputCallback(displayLink, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
        let controller = Unmanaged<MVC>.fromOpaque(displayLinkContext!).takeUnretainedValue()
        controller.updatePlaybackPosition()
        return kCVReturnSuccess
    }, Unmanaged.passUnretained(self).toOpaque())
    CVDisplayLinkStart(displayLink)
}
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
