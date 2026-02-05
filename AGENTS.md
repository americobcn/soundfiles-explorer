# AGENTS.md

Guidelines for agentic coding agents working on this macOS audio file explorer application.

## Project Overview

macOS audio file explorer built with Swift and AppKit. Parses BEXT/iXML metadata from WAV files and displays multi-channel waveforms with playback.

**Key Constraint**: No SwiftUI or Storyboards. Pure AppKit/NSView implementation.

## Build Commands

```bash
# Build the application (Release)
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Release

# Build (Debug)
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Debug

# Build and run
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Debug && open build/Debug/soundfiles-explorer.app

# Clean build
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer clean
```

**Note**: This is an Xcode project, not Swift Package Manager. No `swift build` available.

## Testing

**Current Status**: No unit test target configured in the project.

To add tests in the future:
1. Add test target via Xcode: File → New → Target → Unit Testing Bundle
2. Run tests: `xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer`
3. Run single test: `xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -only-testing:soundfiles-explorerTests/TestClass/testMethod`

**Manual Testing**:
1. Build and run the application
2. Drag audio files (WAV with BEXT/iXML chunks) into the window
3. Use keyboard shortcuts: Space/K (play/pause), J (rewind), L (fast-forward)
4. Click waveform to seek, use zoom slider to adjust view

## Code Style Guidelines

### Formatting
- **Indentation**: 4 spaces (no tabs)
- **Line length**: No strict limit, keep reasonable (< 120 chars preferred)
- **Braces**: Opening brace on same line, closing brace on new line
- **Whitespace**: Single blank line between methods, blank line after MARK comments

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
- **Types**: PascalCase (`AudioMetadataReader`, `BEXTMetadata`)
- **Properties/Variables**: camelCase (`currentTime`, `sampleRate`)
- **Constants**: camelCase for local, uppercase snake for global (`maxCacheSize`)
- **Methods**: camelCase with verb prefix (`loadAudioFile()`, `generateWaveforms()`)
- **Protocols**: PascalCase with descriptor suffix (`AudioParserDelegate`)
- **Enums**: PascalCase, cases lowercase unless representing types (`case invalidFile`)
- **Private members**: No underscore prefix (use `private` access modifier)

### Types
- Prefer `let` over `var`
- Use `Int`, `Double`, `Float` (not `CGFloat` unless UI-related)
- Use `TimeInterval` for time values
- Use explicit types for public APIs, inference allowed for local variables
- Use `Result` type for async operations with multiple outcomes

### Error Handling
- Define custom errors as enums conforming to `Error`, `LocalizedError`
- Use `guard` for early returns, `if let` for optional binding
- Example pattern from codebase:
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

// Usage:
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
- Common imports: `Foundation`, `Cocoa`, `AVFoundation`, `AVKit`

### Comments
- Use `//` for single-line comments
- Use `/* */` only for temporarily disabling code blocks
- Use `// MARK: - Section Name` to organize files
- Document public APIs with `///` doc comments
- Avoid obvious comments (`// increment i`)

### Architecture Patterns
- MVC pattern used throughout
- NSView subclasses for custom UI (no SwiftUI)
- NotificationCenter for loose coupling between components
- Async/await for asynchronous operations
- Private nested classes for file-local types

### Auto Layout
- Use `NSLayoutConstraint.activate([...])` for batch constraint activation
- Set `translatesAutoresizingMaskIntoConstraints = false` for programmatic UI

### Key Files
- `MVC.swift`: Main view controller
- `AudioMetadataReader.swift`: BEXT/iXML parsing
- `AudioWaveformView.swift`: Waveform visualization
- `AudioPlaybackManager.swift`: Audio playback control
- `AudioParserError.swift`: Error definitions

### Frameworks
- AppKit for UI (NSView, NSWindow, NSButton, etc.)
- AVFoundation for audio playback and metadata
- CoreMedia for time calculations (CMTime)
- No external dependencies (pure Apple frameworks)

### Audio File Support
- WAV (recommended, supports BEXT/iXML)
- AIFF, CAF, MP3, M4A (basic support)

### Keyboard Shortcuts (Implemented)
- Space/K: Play/Pause
- J: Rewind (scrub backward)
- L: Fast forward (scrub forward)
- Delete: Remove selected rows
- Arrow keys: Navigate waveform (with Shift/Cmd modifiers)
