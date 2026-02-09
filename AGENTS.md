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

# Run all tests (no test target configured)
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer

# Run single test (when test target is added)
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -only-testing:soundfiles-explorerTests/TestClass/testMethod
```

**Note**: Xcode project (not SPM). No `swift build` available.

## Testing

**Current Status**: No unit test target configured.

To add tests: File → New → Target → Unit Testing Bundle, then run `xcodebuild test`.

**Manual Testing**: Drag WAV files with BEXT/iXML chunks, use Space/K (play/pause), J/L (seek), click waveform to seek.

## Code Style

### Formatting
- 4 spaces, no tabs
- Braces on same line
- Single blank line between methods, after MARK comments

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

### Naming
- Types: PascalCase (`AudioMetadataReader`)
- Variables: camelCase (`currentTime`)
- Constants: camelCase local, UPPER_SNAKE global (`maxCacheSize`)
- Methods: camelCase verb prefix (`loadAudioFile()`)
- Protocols: PascalCase descriptor suffix (`AudioParserDelegate`)
- Enums: PascalCase, lowercase cases (`case invalidFile`)
- Private: No underscore prefix, use `private` modifier

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
        case .noAudioTrack: return "No audio track found in the asset."
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
- Common: `Foundation`, `Cocoa`, `AVFoundation`, `AVKit`

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
- Private nested classes for file-local types

### Auto Layout
- `NSLayoutConstraint.activate([...])` for batch activation
- `translatesAutoresizingMaskIntoConstraints = false` for programmatic UI

## Key Files
- `MVC.swift`: Main view controller
- `AudioMetadataReader.swift`: BEXT/iXML parsing
- `AudioWaveformView.swift`: Waveform visualization
- `AudioPlaybackManager.swift`: Audio playback control
- `AudioParserError.swift`: Error definitions

## Frameworks
- AppKit (NSView, NSWindow, etc.)
- AVFoundation (audio, metadata)
- CoreMedia (CMTime)
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
