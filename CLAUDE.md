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

- **`src/MVC.swift`** — Main `NSViewController` subclass. Owns the table view, waveform view, controls, and ties all components together. Also the `NSTableViewDataSource`/`NSTableViewDelegate`. `loadProject(_:)` rehydrates the table from a persisted `Project`.
- **`src/AudioFileLoader.swift`** — Loads audio files, extracts waveform data (`[[Float]]` per channel). Two-tier waveform cache: in-memory `NSCache` (L1) + on-disk `WaveformDiskCache` (L2, files keyed by an FNV-1a hash of URL+mtime so they survive restarts). Defines `AudioFileInfo` (the model object), incl. `bext`/`ixml`.
- **`src/AudioMetadataReader.swift`** — Parses raw BEXT and iXML chunks from WAV files into `BEXTMetadata` / `IXMLMetadata` structs (both `Codable` so they can be persisted in `AudioFileRecord`).
- **`src/AudioPlaybackManager.swift`** — Wraps `AVAudioPlayer` for play/pause/seek. Posts `AudioPlaybackStateChanged` notifications.
- **`src/AudioParserError.swift`** — Custom `Error` types with `LocalizedError` conformance.
- **`src/AudioRegionExporter.swift`** — Exports a selected waveform region to a new WAV file (drag-to-DAW), preserving BEXT/iXML metadata.
- **`src/FolderScanner.swift`** — Scans dropped/added folders for audio files and sound-report documents, returning a `ScanResult`.
- **`src/ProjectModels.swift`** — `Codable` models persisted to disk: `Project`, `AudioFileRecord` (flattened metadata + `bext`/`ixml`), `SoundReportRecord`.
- **`src/ProjectStore.swift`** — Loads/saves `projects.json` (`~/Library/Application Support/com.americobcn.soundfiles-explorer/`), tracks `activeProject`, posts project change notifications.
- **`Views/AudioWaveformView.swift`** — `NSView` subclass rendering per-channel waveforms using `CALayer`. Exposes `currentTime`, `pixelsPerSecond`, `waveformColors`, etc. Posts `AudioWaveformViewDidSeek` notification on click-to-seek.
- **`Views/AudioWaveformExtensions.swift`** — Extensions supporting the waveform view.
- **`Views/AC3TableView.swift`** — Custom `NSTableView` subclass.
- **`Views/ProjectSidebarViewController.swift`** — Sidebar listing persisted projects and sound reports; selecting a project drives `MVC.loadProject`.

### Data Flow

```
Drop files → AudioFileLoader → AudioFileInfo (model)
                             → AudioMetadataReader → BEXTMetadata / IXMLMetadata
MVC (controller) → AudioWaveformView (renders [[Float]] waveform data)
               → AudioPlaybackManager (drives AVAudioPlayer)
               → CADisplayLink → updates waveformView.currentTime at 60fps
```

Reopening a project (sidebar selection) skips re-parsing where possible:

```
Reopen app → ProjectStore loads projects.json → sidebar lists projects
Select project → MVC.loadProject rehydrates AudioFileInfo from AudioFileRecord
                  (scene/take/date/bext/ixml + waveform from WaveformDiskCache if cached)
              → only files with no waveform cache entry go through the AudioFileLoader
                pipeline above
FileMetadataLoaded → ProjectStore.updateAudioFileRecord persists refreshed bext/ixml/etc.
```

### Notifications (loose coupling between components)

| Name | Direction | Payload |
|------|-----------|---------|
| `AudioWaveformViewDidSeek` | View → Controller | `["time": TimeInterval]` |
| `AudioWaveformViewSelectionChanged` | View → Controller | `["start": TimeInterval, "end": TimeInterval]` or none |
| `AudioWaveformViewWillBeginDrag` | View → Controller | `["event": NSEvent, "regionStart": TimeInterval, "regionEnd": TimeInterval]` |
| `AudioWaveformViewTogglePlayback` | View → Controller | — |
| `AudioPlaybackStateChanged` | Manager → Controller | `["isPlaying": Bool]` |
| `FileMetadataLoaded` | Loader → Controller | `["url": URL]` |
| `WaveformGenerationCompleted` | Loader → Controller | `["url": URL, "waveformData": [[Float]]]` |
| `ProjectDidChange` | Store → Controller/Sidebar | `Project?` (object) |
| `ProjectListDidChange` | Store → Sidebar | `Project?` (object) |
| `ProjectDidDelete` | Store → Sidebar | `UUID` (object) |
| `SidebarRequestsFolderScan` | Sidebar → Controller | `["folders": [URL], "scanResult": ScanResult]` |

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
