# Graph Report - .  (2026-06-09)

## Corpus Check
- Corpus is ~45,532 words - fits in a single context window. You may not need a graph.

## Summary
- 403 nodes · 753 edges · 27 communities (21 shown, 6 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 36 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Waveform View Rendering|Waveform View Rendering]]
- [[_COMMUNITY_Audio Metadata & File Loading|Audio Metadata & File Loading]]
- [[_COMMUNITY_WAV Chunk & Region Export|WAV Chunk & Region Export]]
- [[_COMMUNITY_Swift Concurrency Reference Docs|Swift Concurrency Reference Docs]]
- [[_COMMUNITY_Region Exporter & Error Types|Region Exporter & Error Types]]
- [[_COMMUNITY_Playback & UI Controls|Playback & UI Controls]]
- [[_COMMUNITY_AVPlayer Playback Engine|AVPlayer Playback Engine]]
- [[_COMMUNITY_Table Column Layout|Table Column Layout]]
- [[_COMMUNITY_Drag Session & Selection|Drag Session & Selection]]
- [[_COMMUNITY_Drag & Drop Integration|Drag & Drop Integration]]
- [[_COMMUNITY_Concurrency Memory & Tasks|Concurrency Memory & Tasks]]
- [[_COMMUNITY_Region Selection Design Docs|Region Selection Design Docs]]
- [[_COMMUNITY_MVC Utility Methods|MVC Utility Methods]]
- [[_COMMUNITY_Swift Concurrency Patterns|Swift Concurrency Patterns]]
- [[_COMMUNITY_App Lifecycle Entry|App Lifecycle Entry]]
- [[_COMMUNITY_Waveform Format Extensions|Waveform Format Extensions]]
- [[_COMMUNITY_Controller View Setup|Controller View Setup]]
- [[_COMMUNITY_UI Control Widgets|UI Control Widgets]]
- [[_COMMUNITY_Notification Handlers|Notification Handlers]]
- [[_COMMUNITY_Selection & Channel Labels|Selection & Channel Labels]]
- [[_COMMUNITY_Keyboard Playback Controls|Keyboard Playback Controls]]
- [[_COMMUNITY_Accent Color Asset|Accent Color Asset]]
- [[_COMMUNITY_App Icon Asset|App Icon Asset]]
- [[_COMMUNITY_Asset Catalog Root|Asset Catalog Root]]
- [[_COMMUNITY_Claude Settings|Claude Settings]]
- [[_COMMUNITY_Task Local Value|Task Local Value]]
- [[_COMMUNITY_AsyncSequence|AsyncSequence]]

## God Nodes (most connected - your core abstractions)
1. `MVC` - 73 edges
2. `AudioWaveformView` - 53 edges
3. `AudioFileInfo` - 23 edges
4. `AudioFileLoader` - 21 edges
5. `AudioPlaybackManager` - 18 edges
6. `TableColumnIdentifiers` - 18 edges
7. `AudioMetadataReader` - 16 edges
8. `AudioRegionExporter` - 13 edges
9. `CGFloat` - 12 edges
10. `AudioParserError` - 12 edges

## Surprising Connections (you probably didn't know these)
- `AudioFileLoader` --conceptually_related_to--> `nonisolated`  [INFERRED]
  soundfiles-explorer/src/AudioFileLoader.swift → .agents/skills/swift-concurrency/references/actors.md
- `MVC` --conceptually_related_to--> `@MainActor`  [INFERRED]
  soundfiles-explorer/src/MVC.swift → .agents/skills/swift-concurrency/references/actors.md
- `Interaction States Brainstorm (Region Selection)` --conceptually_related_to--> `Region Selection & Drag-to-DAW Design Spec`  [INFERRED]
  .superpowers/brainstorm/3008-1773340030/interaction-states.html → docs/superpowers/specs/2026-03-12-region-selection-drag-design.md
- `Region Selection Visual Style Options` --conceptually_related_to--> `Region Selection & Drag-to-DAW Design Spec`  [INFERRED]
  .superpowers/brainstorm/3008-1773340030/region-selection-style.html → docs/superpowers/specs/2026-03-12-region-selection-drag-design.md
- `AudioWaveformGenerator` --semantically_similar_to--> `AudioWaveformView`  [INFERRED] [semantically similar]
  soundfiles-explorer/Views/AudioWaveformExtensions.swift → soundfiles-explorer/Views/AudioWaveformView.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Notification-Based Loose Coupling (View → Controller → Manager)** — views_audiowaveformview_audiowaveformview, src_mvc_mvc, src_audioplaybackmanager_audioplaybackmanager, concept_notification_audiowaveformviewdidseek, concept_notification_audioplaybackstatechanged, concept_notification_audiowaveformviewselectionchanged [EXTRACTED 1.00]
- **Audio Metadata Pipeline (File → Loader → Reader → Structs → View)** — src_audiofileloader_audiofileloader, src_audiometadatareader_audiometadatareader, src_audiometadatareader_bextmetadata, src_audiometadatareader_ixmlmetadata, src_audiofileloader_audiofileinfo, src_mvc_mvc [EXTRACTED 1.00]
- **Region Drag-to-DAW Export Flow** — views_audiowaveformview_audiowaveformview, concept_notification_audiowaveformviewwillbegindrag, src_mvc_mvc, src_audioregionexporter_audioregionexporter, src_audiofileloader_audiofileinfo [EXTRACTED 1.00]
- **Swift Concurrency Skill Reference Documents** — references_core_data_core_data_and_swift_concurrency, references_glossary_swift_concurrency_glossary, references_linting_linting_and_concurrency, references_memory_management_memory_management, references_migration_migration_to_swift6, references_performance_swift_concurrency_performance, references_sendable_sendable_patterns, references_tasks_tasks_patterns, references_testing_testing_concurrent_code, references_threading_threading_model [EXTRACTED 1.00]
- **Region Selection Design & Implementation Artifacts** — brainstorm_3008_interaction_states_interaction_states, brainstorm_3008_region_selection_style_region_selection_style, specs_2026_03_12_region_selection_drag_design, plans_2026_03_12_region_selection_plan, specs_drag_design_dragstate_enum, specs_drag_design_selection_layer_stack [EXTRACTED 1.00]
- **Swift 6 Migration Core Concepts** — references_migration_concurrency_rabbit_hole, references_migration_approachable_concurrency, references_migration_nonisolated_nonsending, references_threading_nonisolated_nonsending_se461, references_threading_concurrent_attribute [EXTRACTED 1.00]

## Communities (27 total, 6 thin omitted)

### Community 0 - "Waveform View Rendering"
Cohesion: 0.09
Nodes (26): AudioWaveformView, CALayer, CATextLayer, CGContext, CGPoint, CGRect, NSColor, NSDraggingSource (+18 more)

### Community 1 - "Audio Metadata & File Loading"
Cohesion: 0.10
Nodes (27): AudioMetadataReader, AudioStreamBasicDescription, AVAudioFile, BEXTMetadata, Notification: FileMetadataLoaded, Notification: WaveformGenerationCompleted, Two-Level Waveform Cache (Memory + Disk), IXMLMetadata (+19 more)

### Community 2 - "WAV Chunk & Region Export"
Cohesion: 0.15
Nodes (19): BEXT Chunk Binary Format (WAV), iXML Chunk Format (WAV), Region Export with BEXT/iXML Metadata Injection, Int16, IXMLTrack, Data, Int, String (+11 more)

### Community 3 - "Swift Concurrency Reference Docs"
Cohesion: 0.08
Nodes (33): ArticleDAO Pattern, Core Data and Swift Concurrency, CoreDataStore Pattern, NSManagedObjectContextExecutor, Actor Isolation, AsyncStream, Continuation, Cooperative Thread Pool (+25 more)

### Community 4 - "Region Exporter & Error Types"
Cohesion: 0.11
Nodes (23): Error, LocalizedError, String, AudioFileInfo, Data, Double, String, TimeInterval (+15 more)

### Community 5 - "Playback & UI Controls"
Cohesion: 0.13
Nodes (16): Any, AudioPlaybackManager, CADisplayLink, Notification: AudioWaveformViewDidSeek, Notification: AudioWaveformViewSelectionChanged, Notification: AudioWaveformViewWillBeginDrag, Waveform Layer Rendering Strategy (CALayer-based bitmap), NSSearchField (+8 more)

### Community 6 - "AVPlayer Playback Engine"
Cohesion: 0.17
Nodes (7): AVPlayer, Notification: AudioPlaybackStateChanged, AVPlayerItem, Bool, Float, TimeInterval, AudioPlaybackManager

### Community 7 - "Table Column Layout"
Cohesion: 0.12
Nodes (15): CaseIterable, TableColumnIdentifiers, audioDescription, channels, circled, date, duration, fileName (+7 more)

### Community 8 - "Drag Session & Selection"
Cohesion: 0.12
Nodes (12): ClosedRange, NSDraggingContext, NSDraggingSession, Self, NSDragOperation, Comparable, DragState, draggingNewSelection (+4 more)

### Community 9 - "Drag & Drop Integration"
Cohesion: 0.15
Nodes (10): NSDraggingInfo, NSPasteboardWriting, NSTableColumn, AudioFileInfo, Bool, Int, NSDragOperation, NSTableView (+2 more)

### Community 10 - "Concurrency Memory & Tasks"
Cohesion: 0.18
Nodes (14): Isolated deinit (Swift 6.2+), Memory Management in Swift Concurrency, Retain Cycles with Tasks, Weak Self in Tasks Pattern, Detached Tasks, Discarding Task Groups, Structured vs Unstructured Tasks, Task Groups (+6 more)

### Community 11 - "Region Selection Design Docs"
Cohesion: 0.26
Nodes (12): AGENTS.md — Agentic Coding Guidelines, Interaction States Brainstorm (Region Selection), Region Selection Visual Style Options, CLAUDE.md — Project Overview and Architecture, Region Selection Implementation Plan, Region Selection & Drag-to-DAW Design Spec, AudioWaveformViewSelectionChanged Notification, DragState Enum (+4 more)

### Community 12 - "MVC Utility Methods"
Cohesion: 0.21
Nodes (4): Double, Int64, TimeInterval, String

### Community 13 - "Swift Concurrency Patterns"
Cohesion: 0.22
Nodes (11): Actor Isolation, Actor Reentrancy, @MainActor, Mutex, nonisolated, AsyncChannel, debounce operator, async let (+3 more)

### Community 14 - "App Lifecycle Entry"
Cohesion: 0.22
Nodes (6): NSApplication, NSApplicationDelegate, NSWindow, AppDelegate, Bool, Notification

### Community 15 - "Waveform Format Extensions"
Cohesion: 0.31
Nodes (7): AVAudioFormat, Double, Int, String, TimeInterval, URL, AudioFileInfoHelper

### Community 17 - "UI Control Widgets"
Cohesion: 0.33
Nodes (5): NSButton, NSScrollView, NSSlider, NSStackView, NSView

### Community 19 - "Selection & Channel Labels"
Cohesion: 0.33
Nodes (3): Float64, NSTextField, CGFloat

### Community 21 - "Accent Color Asset"
Cohesion: 0.40
Nodes (4): colors, info, author, version

### Community 22 - "App Icon Asset"
Cohesion: 0.40
Nodes (4): images, info, author, version

### Community 23 - "Asset Catalog Root"
Cohesion: 0.50
Nodes (3): info, author, version

## Knowledge Gaps
- **100 isolated node(s):** `allow`, `NSWindow`, `NSApplication`, `Bool`, `colors` (+95 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `MVC` connect `Playback & UI Controls` to `Waveform View Rendering`, `Audio Metadata & File Loading`, `WAV Chunk & Region Export`, `Region Exporter & Error Types`, `AVPlayer Playback Engine`, `Table Column Layout`, `Drag & Drop Integration`, `MVC Utility Methods`, `Swift Concurrency Patterns`, `Controller View Setup`, `UI Control Widgets`, `Notification Handlers`, `Selection & Channel Labels`, `Keyboard Playback Controls`?**
  _High betweenness centrality (0.472) - this node is a cross-community bridge._
- **Why does `AudioWaveformView` connect `Waveform View Rendering` to `Drag Session & Selection`, `UI Control Widgets`, `Playback & UI Controls`?**
  _High betweenness centrality (0.229) - this node is a cross-community bridge._
- **Why does `AudioFileInfo` connect `Audio Metadata & File Loading` to `WAV Chunk & Region Export`, `Region Exporter & Error Types`, `Playback & UI Controls`?**
  _High betweenness centrality (0.113) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `MVC` (e.g. with `@MainActor` and `AC3TableView`) actually correct?**
  _`MVC` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `allow`, `NSWindow`, `NSApplication` to the rest of the system?**
  _101 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Waveform View Rendering` be split into smaller, more focused modules?**
  _Cohesion score 0.0925589836660617 - nodes in this community are weakly interconnected._
- **Should `Audio Metadata & File Loading` be split into smaller, more focused modules?**
  _Cohesion score 0.10299003322259136 - nodes in this community are weakly interconnected._