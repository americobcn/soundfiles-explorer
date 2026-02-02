# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS audio file explorer application built with Swift and AppKit that allows users to:
- View audio files with metadata (BEXT and iXML chunks)
- Display multi-channel audio waveforms with playback cursor
- Search and sort audio files
- Drag and drop audio files into the application
- Play audio files with keyboard shortcuts
- View timecode information from audio files
- Exclude SwiftUI and Storyboards

## Key Components

### Core Architecture
- **MVC.swift**: Main view controller that handles the table view, waveform display, audio playback, and keyboard controls
- **AudioMetadataReader.swift**: Parses audio metadata from BEXT and iXML chunks in WAV files
- **AudioWaveformView.swift**: Custom NSView for displaying multi-channel audio waveforms with playback cursor
- **AudioWaveformViewController.swift**: Controller for the waveform view with playback controls

### Audio Metadata Handling
The application reads and parses:
- BEXT chunks containing technical audio information (sample rate, bit depth, time reference, loudness values, etc.)
- iXML chunks containing project, scene, take, and track information
- Supports parsing of iXML track information for multi-channel audio files

### Waveform Visualization
- Multi-channel waveform display with customizable colors
- Playback cursor that follows audio playback
- Time ruler with automatic scaling
- Zoom and scroll functionality
- Click-to-seek capability
- Auto-scrolling during playback

## Development Commands

### Building
```bash
# Build the application using Xcode or command line
xcodebuild -project soundfiles-explorer.xcodeproj -scheme soundfiles-explorer -configuration Release
```

### Running
```bash
# Run the application (requires Xcode)
open -a "soundfiles-explorer"
```

### Testing
The project doesn't appear to have unit tests, but you can test functionality by:
1. Running the application
2. Dragging audio files into the application window
3. Using keyboard shortcuts for playback controls

## Key Files and Functions

### Main View Controller (MVC.swift)
- Handles table view data source and delegate methods
- Manages audio playback using AVPlayer
- Implements keyboard event handling for playback controls
- Integrates with AudioWaveformView for waveform display
- Processes drag and drop operations for audio files

### Metadata Reader (AudioMetadataReader.swift)
- Parses BEXT chunks for technical audio information
- Parses iXML chunks for project metadata
- Extracts track information from iXML data
- Provides helper functions for formatting timecodes and audio descriptions

### Waveform View (AudioWaveformView.swift)
- Displays multi-channel audio waveforms
- Shows playback cursor that follows audio position
- Implements zoom and scroll functionality
- Handles click-to-seek events
- Customizable colors and appearance

## Keyboard Shortcuts
- Space or K: Play/Pause
- J: Rewind
- L: Fast forward
- Return: Stop and go to start/end
- Delete: Delete selected rows

## Development Notes

### Audio File Support
The application supports standard audio formats that can be read by AVAudioFile:
- WAV (recommended for multi-channel)
- AIFF
- CAF
- MP3
- M4A

### Data Structure
Audio files are stored in an `audioFiles` array of `AudioFile` objects, which contain:
- File name and URL
- Metadata from BEXT and iXML chunks
- Audio properties (channels, bit depth, sample rate)
- Timecode information

### Key Features Implemented
1. Table view with metadata display
2. Multi-channel waveform visualization
3. Playback controls with keyboard shortcuts
4. Drag and drop support for audio files
5. Search functionality
6. Timecode conversion from sample references
7. iXML track information parsing

### Customization Options
- Waveform colors can be customized per channel
- Background color and cursor color are customizable
- Grid and text colors are customizable
- Channel names can be set for better identification
- Zoom level can be adjusted (10-1000 pixels per second)
