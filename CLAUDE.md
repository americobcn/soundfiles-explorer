# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

macOS audio file explorer built with Swift and AppKit. Parses BEXT/iXML metadata from WAV files, displays multi-channel waveforms with playback controls.

**Key Constraint**: Pure AppKit/NSView — no SwiftUI, no Storyboards.

## Build & Run Commands

```bash
# Build (Debug)
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Debug

# Build (Release)
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Release

# Clean
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer clean

# Test (no test target configured yet)
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer
xcodebuild test -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -only-testing:soundfiles-explorerTests/MyTestClass/testMethodName
```

> Xcode project (not SPM). `swift build` does not apply.

## Architecture

MVC pattern throughout. Key files:

- **`src/MVC.swift`** — Main `NSViewController` subclass. Owns the table view, waveform view, controls, and ties all components together. Also the `NSTableViewDataSource`/`NSTableViewDelegate`.
- **`src/AudioFileLoader.swift`** — Loads audio files, extracts waveform data (`[[Float]]` per channel), and caches results via `NSCache`. Defines `AudioFileInfo` (the model object).
- **`src/AudioMetadataReader.swift`** — Parses raw BEXT and iXML chunks from WAV files into `BEXTMetadata` / `IXMLMetadata` structs.
- **`src/AudioPlaybackManager.swift`** — Wraps `AVAudioPlayer` for play/pause/seek. Posts `AudioPlaybackStateChanged` notifications.
- **`src/AudioParserError.swift`** — Custom `Error` types with `LocalizedError` conformance.
- **`Views/AudioWaveformView.swift`** — `NSView` subclass rendering per-channel waveforms using `CALayer`. Exposes `currentTime`, `pixelsPerSecond`, `waveformColors`, etc. Posts `AudioWaveformViewDidSeek` notification on click-to-seek.
- **`Views/AudioWaveformExtensions.swift`** — Extensions supporting the waveform view.
- **`Views/AC3TableView.swift`** — Custom `NSTableView` subclass.

### Data Flow

```
Drop files → AudioFileLoader → AudioFileInfo (model)
                             → AudioMetadataReader → BEXTMetadata / IXMLMetadata
MVC (controller) → AudioWaveformView (renders [[Float]] waveform data)
               → AudioPlaybackManager (drives AVAudioPlayer)
               → CADisplayLink → updates waveformView.currentTime at 60fps
```

### Notifications (loose coupling between components)

| Name | Direction | Payload |
|------|-----------|---------|
| `AudioWaveformViewDidSeek` | View → Controller | `["time": TimeInterval]` |
| `AudioPlaybackStateChanged` | Manager → Controller | — |

## Code Style

- 4 spaces, braces on same line, soft 120-char / hard 160-char line limit.
- `MARK: -` sections: Types/Protocols → Main Class → Private Extensions → Public Methods → Private Methods.
- `private` by default; `final` on classes unless inheritance is needed.
- `MainActor` for all UI updates; `async/await` for async operations.
- `TimeInterval` for time values; `CGFloat` only for UI geometry.

## Swift & Platform

- Swift 5.0+ with Swift Concurrency (async/await, `@MainActor`).
- Deployment target: macOS 14.6+ (Xcode 26.2).
- Frameworks: AppKit, AVFoundation, CoreMedia. **No external dependencies.**

## Keyboard Shortcuts (for manual testing)

- **Space / K**: Play/Pause
- **J**: Rewind
- **L**: Fast forward
- **Delete**: Remove selected rows
- **Arrow keys**: Navigate waveform (Shift/Cmd modifiers supported)
