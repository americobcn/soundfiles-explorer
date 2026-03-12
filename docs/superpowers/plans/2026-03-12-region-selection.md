# Region Selection Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add interactive region selection to `AudioWaveformView` — drag to select, dim outside, resize edges, stop playback at region end.

**Architecture:** Six new CALayers overlay the existing waveform bitmap without touching it. A `DragState` enum drives all mouse interaction. The waveform bitmap cache is never invalidated during selection interactions — all selection feedback is pure layer geometry.

**Tech Stack:** AppKit, CoreAnimation (CALayer, CATextLayer), Swift 5, macOS 14.6+. No external dependencies. No test target — verify manually per step.

**Spec:** `docs/superpowers/specs/2026-03-12-region-selection-drag-design.md`

---

## Chunk 1: Selection Layer Infrastructure

### Task 1: Add selection layers and `selectionRegion` property

**Files:**
- Modify: `soundfiles-explorer/Views/AudioWaveformView.swift` (setupView, properties section)

- [ ] **Step 1.1 — Add layer properties after `rulerLayer`**

  In `AudioWaveformView`, after the `private var rulerLayer: CALayer?` declaration (around line 81), add:

  ```swift
  // MARK: - Selection Layers
  private var leftDimLayer: CALayer?
  private var rightDimLayer: CALayer?
  private var selectionBorderLayer: CALayer?
  private var leftHandleLayer: CALayer?
  private var rightHandleLayer: CALayer?
  private var durationBadgeLayer: CATextLayer?
  ```

- [ ] **Step 1.2 — Add `selectionRegion` property after `needsWaveformUpdate`**

  After `private var needsWaveformUpdate = true`, add:

  ```swift
  /// Currently selected time region. Setting this updates all selection layers.
  private(set) var selectionRegion: (start: TimeInterval, end: TimeInterval)? {
      didSet { updateSelectionLayers() }
  }
  ```

- [ ] **Step 1.3 — Create and add selection layers inside `setupView()`**

  At the end of `setupView()`, before the closing brace, add:

  ```swift
  // Left dim overlay (outside selection, left side)
  let leftDim = CALayer()
  leftDim.zPosition = 20
  leftDim.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.5).cgColor
  leftDim.isHidden = true
  layer?.addSublayer(leftDim)
  leftDimLayer = leftDim

  // Right dim overlay (outside selection, right side)
  let rightDim = CALayer()
  rightDim.zPosition = 21
  rightDim.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.5).cgColor
  rightDim.isHidden = true
  layer?.addSublayer(rightDim)
  rightDimLayer = rightDim

  // Selection border (white outline around selected region)
  let border = CALayer()
  border.zPosition = 22
  border.backgroundColor = NSColor.clear.cgColor
  border.borderColor = NSColor.white.withAlphaComponent(0.75).cgColor
  border.borderWidth = 1.5
  border.isHidden = true
  layer?.addSublayer(border)
  selectionBorderLayer = border

  // Left resize handle (pill grip on left edge)
  let lHandle = CALayer()
  lHandle.zPosition = 23
  lHandle.backgroundColor = NSColor.white.withAlphaComponent(0.85).cgColor
  lHandle.cornerRadius = 3
  lHandle.isHidden = true
  layer?.addSublayer(lHandle)
  leftHandleLayer = lHandle

  // Right resize handle (pill grip on right edge)
  let rHandle = CALayer()
  rHandle.zPosition = 24
  rHandle.backgroundColor = NSColor.white.withAlphaComponent(0.85).cgColor
  rHandle.cornerRadius = 3
  rHandle.isHidden = true
  layer?.addSublayer(rHandle)
  rightHandleLayer = rHandle

  // Duration badge (text label inside selection)
  let badge = CATextLayer()
  badge.zPosition = 25
  badge.fontSize = 10
  // Note: CATextLayer.font expects CFTypeRef — cast explicitly to avoid runtime warning.
  // fontSize alone is sufficient; the cast ensures Core Animation uses the correct font object.
  badge.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium) as CFTypeRef
  badge.foregroundColor = NSColor.white.cgColor
  badge.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.12).cgColor
  badge.cornerRadius = 3
  badge.alignmentMode = .center
  badge.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
  badge.isHidden = true
  layer?.addSublayer(badge)
  durationBadgeLayer = badge

  // Disable implicit animations on all selection layers
  let noAnimation = ["position": NSNull(), "bounds": NSNull(), "frame": NSNull(),
                     "hidden": NSNull(), "backgroundColor": NSNull()]
  leftDim.actions = noAnimation
  rightDim.actions = noAnimation
  border.actions = noAnimation
  lHandle.actions = noAnimation
  rHandle.actions = noAnimation
  badge.actions = noAnimation
  ```

- [ ] **Step 1.4 — Build and confirm it compiles**

  ```bash
  xcodebuild -project "soundfiles-explorer/soundfiles-explorer.xcodeproj" \
    -scheme soundfiles-explorer -configuration Debug 2>&1 | tail -5
  ```

  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 1.5 — Commit**

  ```bash
  git add soundfiles-explorer/soundfiles-explorer/Views/AudioWaveformView.swift
  git commit -m "feat: add selection CALayer infrastructure to AudioWaveformView"
  ```

---

### Task 2: Implement `updateSelectionLayers()`

**Files:**
- Modify: `soundfiles-explorer/Views/AudioWaveformView.swift` (new private method in Layer Rendering section)

- [ ] **Step 2.1 — Add `updateSelectionLayers()` in the Layer Rendering section**

  Add this method after `updateCursorLayer()` (around line 479):

  ```swift
  /// Updates all selection layer frames and visibility. Called whenever selectionRegion changes.
  /// Never re-renders the waveform bitmap — only repositions layers.
  private func updateSelectionLayers() {
      let hidden = selectionRegion == nil
      leftDimLayer?.isHidden = hidden
      rightDimLayer?.isHidden = hidden
      selectionBorderLayer?.isHidden = hidden
      leftHandleLayer?.isHidden = hidden
      rightHandleLayer?.isHidden = hidden
      durationBadgeLayer?.isHidden = hidden

      guard let region = selectionRegion else { return }

      let h = bounds.height
      let leftX  = CGFloat(region.start) * pixelsPerSecond
      let rightX = CGFloat(region.end)   * pixelsPerSecond

      // Left dim: from 0 to selection start
      leftDimLayer?.frame  = CGRect(x: 0,      y: 0, width: leftX,              height: h)
      // Right dim: from selection end to full content width
      let totalWidth = getTotalWidth()
      rightDimLayer?.frame = CGRect(x: rightX, y: 0, width: max(0, totalWidth - rightX), height: h)
      // Border: exactly over the selection
      selectionBorderLayer?.frame = CGRect(x: leftX, y: 0, width: rightX - leftX, height: h)

      // Handles: pill shape, vertically centred on each edge
      let handleW: CGFloat = 9
      let handleH: CGFloat = 20
      let handleY = (h - handleH) / 2
      leftHandleLayer?.frame  = CGRect(x: leftX  - handleW / 2, y: handleY, width: handleW, height: handleH)
      rightHandleLayer?.frame = CGRect(x: rightX - handleW / 2, y: handleY, width: handleW, height: handleH)

      // Duration badge: centred inside selection, near top
      let regionDuration = region.end - region.start
      let durationText = formatTime(regionDuration)
      let badgeW: CGFloat = 60
      let badgeH: CGFloat = 16
      let badgeCenterX = leftX + (rightX - leftX) / 2
      durationBadgeLayer?.string = durationText
      durationBadgeLayer?.frame = CGRect(
          x: badgeCenterX - badgeW / 2,
          y: 4,
          width: badgeW,
          height: badgeH
      )

      // Post selection-changed notification
      NotificationCenter.default.post(
          name: NSNotification.Name("AudioWaveformViewSelectionChanged"),
          object: self,
          userInfo: ["start": region.start, "end": region.end]
      )
  }
  ```

- [ ] **Step 2.2 — Hook `updateSelectionLayers()` into `pixelsPerSecond` didSet**

  Find the existing `pixelsPerSecond` didSet (around line 66):

  ```swift
  var pixelsPerSecond: CGFloat = 100 {
      didSet {
          needsDisplay = true
      }
  }
  ```

  Replace with:

  ```swift
  var pixelsPerSecond: CGFloat = 100 {
      didSet {
          needsDisplay = true
          updateSelectionLayers()
      }
  }
  ```

- [ ] **Step 2.3 — Reset `selectionRegion` in `setWaveformData`, `clearWaveform`, `showLoadingState`**

  In `setWaveformData(...)`, add `selectionRegion = nil` as the very first line of the function body (before touching `channelWaveforms`):

  ```swift
  func setWaveformData(...) {
      selectionRegion = nil   // ← add this
      self.channelWaveforms = waveformData
      // ... rest unchanged
  }
  ```

  In `showLoadingState(...)`, add `selectionRegion = nil` as the very first line:

  ```swift
  func showLoadingState(...) {
      selectionRegion = nil   // ← add this
      self.channelWaveforms = []
      // ... rest unchanged
  }
  ```

  In `clearWaveform()`, add `selectionRegion = nil` as the very first line:

  ```swift
  func clearWaveform() {
      selectionRegion = nil   // ← add this
      self.channelWaveforms = []
      // ... rest unchanged
  }
  ```

- [ ] **Step 2.4 — Build**

  ```bash
  xcodebuild -project "soundfiles-explorer/soundfiles-explorer.xcodeproj" \
    -scheme soundfiles-explorer -configuration Debug 2>&1 | tail -5
  ```

  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2.5 — Commit**

  ```bash
  git add soundfiles-explorer/soundfiles-explorer/Views/AudioWaveformView.swift
  git commit -m "feat: implement updateSelectionLayers() and wire reset on file load"
  ```

---

## Chunk 2: Mouse Interaction State Machine

### Task 3: Add `DragState` enum and rewrite mouse handlers

**Files:**
- Modify: `soundfiles-explorer/Views/AudioWaveformView.swift` (Mouse Interaction section)

- [ ] **Step 3.1 — Add `DragState` enum and `dragState` property**

  Before the `// MARK: - Mouse Interaction` comment, add:

  ```swift
  // MARK: - Selection Interaction State

  private enum DragState {
      case idle
      case draggingNewSelection(anchorTime: TimeInterval)
      case resizingLeft(originalEnd: TimeInterval)
      case resizingRight(originalStart: TimeInterval)
  }

  private var dragState: DragState = .idle
  ```

- [ ] **Step 3.2 — Add hit-test helper**

  In the `// MARK: - Mouse Interaction` section, add before `mouseDown`:

  ```swift
  /// Returns the X position in view coordinates of the left/right selection handles.
  private func selectionHandleX() -> (left: CGFloat, right: CGFloat)? {
      guard let region = selectionRegion else { return nil }
      return (
          left:  CGFloat(region.start) * pixelsPerSecond,
          right: CGFloat(region.end)   * pixelsPerSecond
      )
  }
  ```

- [ ] **Step 3.3 — Replace `mouseDown(with:)` with the new branching logic**

  Replace the existing `mouseDown` implementation entirely:

  ```swift
  override func mouseDown(with event: NSEvent) {
      let location = convert(event.locationInWindow, from: nil)
      guard location.x >= 0 else { return }

      let clickedTime = TimeInterval(location.x / pixelsPerSecond)
      let edgeHitZone: CGFloat = 8

      // Branch 1 & 2: edge resize hit-test (takes priority)
      if let handles = selectionHandleX() {
          if abs(location.x - handles.left) <= edgeHitZone {
              dragState = .resizingLeft(originalEnd: selectionRegion!.end)
              return
          }
          if abs(location.x - handles.right) <= edgeHitZone {
              dragState = .resizingRight(originalStart: selectionRegion!.start)
              return
          }
      }

      // Branch 3: click inside existing selection → deselect, no seek
      if let region = selectionRegion,
         clickedTime >= region.start && clickedTime <= region.end {
          selectionRegion = nil
          dragState = .idle
          NotificationCenter.default.post(
              name: NSNotification.Name("AudioWaveformViewSelectionChanged"),
              object: self,
              userInfo: nil
          )
          return
      }

      // Branch 4: click outside → start a new selection drag (no seek while dragging)
      selectionRegion = nil
      dragState = .draggingNewSelection(anchorTime: clickedTime)
  }
  ```

- [ ] **Step 3.4 — Add `mouseDragged(with:)`**

  After `mouseDown`, add:

  ```swift
  override func mouseDragged(with event: NSEvent) {
      let location = convert(event.locationInWindow, from: nil)
      let nowTime = TimeInterval(max(0, location.x) / pixelsPerSecond).clamped(to: 0...duration)

      switch dragState {
      case .draggingNewSelection(let anchor):
          selectionRegion = (start: min(anchor, nowTime), end: max(anchor, nowTime))

      case .resizingLeft(let originalEnd):
          let newStart = min(nowTime, originalEnd)
          let newEnd   = max(nowTime, originalEnd)
          selectionRegion = (start: newStart, end: newEnd)
          // Swap state if user dragged past the original end
          if nowTime > originalEnd {
              dragState = .resizingRight(originalStart: originalEnd)
          }
          // Amber tint on badge while resizing
          durationBadgeLayer?.backgroundColor = NSColor(calibratedRed: 1, green: 0.77, blue: 0, alpha: 0.35).cgColor

      case .resizingRight(let originalStart):
          let newStart = min(nowTime, originalStart)
          let newEnd   = max(nowTime, originalStart)
          selectionRegion = (start: newStart, end: newEnd)
          if nowTime < originalStart {
              dragState = .resizingLeft(originalEnd: originalStart)
          }
          durationBadgeLayer?.backgroundColor = NSColor(calibratedRed: 1, green: 0.77, blue: 0, alpha: 0.35).cgColor

      case .idle:
          break
      }
  }
  ```

  You will also need a `clamped` helper for `TimeInterval`. First, search the project for an existing one:

  ```bash
  grep -r "func clamped" soundfiles-explorer/
  ```

  If nothing is found, add this file-private extension at the bottom of `AudioWaveformView.swift` (before or after the existing `// MARK: - Waveform Caching` extension):

  ```swift
  // File-private to avoid collision with any future project-wide Comparable extension
  private extension Comparable {
      func clamped(to range: ClosedRange<Self>) -> Self {
          Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
      }
  }
  ```

  Note: qualifying with `Swift.min`/`Swift.max` avoids any ambiguity with overloaded global `min`/`max` in scope.

- [ ] **Step 3.5 — Add `mouseUp(with:)`**

  After `mouseDragged`, add:

  ```swift
  override func mouseUp(with event: NSEvent) {
      defer { dragState = .idle }

      // Reset badge tint to default translucent white
      durationBadgeLayer?.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.12).cgColor

      switch dragState {
      case .draggingNewSelection(let anchorTime):
          // Discard tiny accidental selections (< 50ms) and treat as a seek click instead.
          // Use anchorTime (from mouseDown) as the seek target — this is the original press
          // position, which is more accurate than the mouseUp location for a click.
          if let region = selectionRegion, region.end - region.start < 0.05 {
              selectionRegion = nil
              NotificationCenter.default.post(
                  name: NSNotification.Name("AudioWaveformViewSelectionChanged"),
                  object: self,
                  userInfo: nil
              )
              // Fall through to seek
              let seekTime = max(0, min(duration, anchorTime))
              currentTime = seekTime
              NotificationCenter.default.post(
                  name: NSNotification.Name("AudioWaveformViewDidSeek"),
                  object: self,
                  userInfo: ["time": seekTime]
              )
          }
          // If selection is valid (>= 50ms), keep it — no seek.

      case .resizingLeft, .resizingRight:
          // Region already normalized by mouseDragged; nothing to do.
          break

      case .idle:
          // mouseDown always transitions out of .idle, so this branch is unreachable
          // in normal usage. Kept for exhaustiveness.
          break
      }
  }
  ```

- [ ] **Step 3.6 — Build**

  ```bash
  xcodebuild -project "soundfiles-explorer/soundfiles-explorer.xcodeproj" \
    -scheme soundfiles-explorer -configuration Debug 2>&1 | tail -5
  ```

  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3.7 — Manual smoke test**

  Run the app. Load an audio file. Try:
  - Drag across the waveform → dim layers appear, duration badge shows
  - Release → selection stays with white border and handles
  - Click outside selection → selection clears
  - Click-to-seek still works (seek on mouse-up on empty waveform)

- [ ] **Step 3.8 — Commit**

  ```bash
  git add soundfiles-explorer/soundfiles-explorer/Views/AudioWaveformView.swift
  git commit -m "feat: implement DragState machine and mouse handlers for region selection"
  ```

---

### Task 4: Tracking area and cursor changes

**Files:**
- Modify: `soundfiles-explorer/Views/AudioWaveformView.swift`

- [ ] **Step 4.1 — Add `updateTrackingAreas()` override**

  Add a new tracking-area property after `dragState`:

  ```swift
  private var selectionTrackingArea: NSTrackingArea?
  ```

  Then add the override in the Mouse Interaction section:

  ```swift
  override func updateTrackingAreas() {
      super.updateTrackingAreas()
      if let old = selectionTrackingArea {
          removeTrackingArea(old)
      }
      let area = NSTrackingArea(
          rect: bounds,
          options: [.mouseMoved, .cursorUpdate, .activeInKeyWindow],
          owner: self,
          userInfo: nil
      )
      addTrackingArea(area)
      selectionTrackingArea = area
  }
  ```

- [ ] **Step 4.2 — Add `mouseMoved` and `cursorUpdate`**

  After `updateTrackingAreas()`, add:

  ```swift
  override func mouseMoved(with event: NSEvent) {
      updateCursorForLocation(convert(event.locationInWindow, from: nil))
  }

  override func cursorUpdate(with event: NSEvent) {
      updateCursorForLocation(convert(event.locationInWindow, from: nil))
  }

  private func updateCursorForLocation(_ location: CGPoint) {
      guard let handles = selectionHandleX() else {
          NSCursor.arrow.set()
          return
      }
      let edgeHitZone: CGFloat = 8
      if abs(location.x - handles.left) <= edgeHitZone ||
         abs(location.x - handles.right) <= edgeHitZone {
          NSCursor.resizeLeftRight.set()
      } else {
          NSCursor.arrow.set()
      }
  }
  ```

- [ ] **Step 4.3 — Build**

  ```bash
  xcodebuild -project "soundfiles-explorer/soundfiles-explorer.xcodeproj" \
    -scheme soundfiles-explorer -configuration Debug 2>&1 | tail -5
  ```

  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4.4 — Manual test: cursor**

  Run the app, load a file, draw a selection. Hover over the left/right edge → cursor should change to `↔`. Move away from edges → cursor back to arrow.

- [ ] **Step 4.5 — Commit**

  ```bash
  git add soundfiles-explorer/soundfiles-explorer/Views/AudioWaveformView.swift
  git commit -m "feat: add tracking area and resize cursor on selection edge hover"
  ```

---

## Chunk 3: Playback Integration

### Task 5: Stop playback at region end

**Files:**
- Modify: `soundfiles-explorer/soundfiles-explorer/src/MVC.swift`

- [ ] **Step 5.1 — Add region-end check in `updatePlaybackPosition()`**

  Find `updatePlaybackPosition()` in `MVC.swift` (around line 744):

  ```swift
  @objc private func updatePlaybackPosition() {
      let ct = audioPlaybackManager.getCurrentTimeDirect()
      self.waveformView.currentTime = ct
      self.updateTimeLabel(ct)
      self.scrollToFollowPlayback(ct)
  }
  ```

  Replace with:

  ```swift
  @objc private func updatePlaybackPosition() {
      let ct = audioPlaybackManager.getCurrentTimeDirect()
      self.waveformView.currentTime = ct
      self.updateTimeLabel(ct)
      self.scrollToFollowPlayback(ct)

      // Stop at region end when a selection is active
      if let region = waveformView.selectionRegion,
         audioPlaybackManager.isPlaying,
         ct >= region.end {
          audioPlaybackManager.pause()
          // AudioPlaybackStateChanged will pause the display link on next tick;
          // isPlaying guard above prevents a double-pause.
      }
  }
  ```

- [ ] **Step 5.2 — Build**

  ```bash
  xcodebuild -project "soundfiles-explorer/soundfiles-explorer.xcodeproj" \
    -scheme soundfiles-explorer -configuration Debug 2>&1 | tail -5
  ```

  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5.3 — Manual test: playback stop at region end**

  - Load a file, draw a selection in the middle of the waveform
  - Position playhead before the selection (click-to-seek on empty area before selection, then deselect, redraw)
  - Press Space to play → playback should stop when the cursor reaches the right edge of the selection

- [ ] **Step 5.4 — Commit**

  ```bash
  git add soundfiles-explorer/soundfiles-explorer/src/MVC.swift
  git commit -m "feat: stop playback at selection region end"
  ```

---

## Final Verification Checklist

Run the app and verify each item from the spec:

- [ ] **Selection draw** — drag in waveform → dim layers appear outside, white border inside, duration badge visible
- [ ] **Edge resize** — hover near edge → `↔` cursor; drag → region trims live, badge turns amber
- [ ] **Discard tiny selection** — click without dragging → no region created
- [ ] **Deselect** — click *inside* an existing selection → selection clears, no seek, no playhead move
- [ ] **Click-to-seek** — click on empty waveform (no selection, short click < 50ms drag) → playhead moves to click position
- [ ] **Playback stop** — with region selected, press play → playback stops at region end
- [ ] **Zoom** — draw selection, change zoom slider → layers reposition correctly, no bitmap re-render
- [ ] **File switch** — draw selection, select a different file in the table → selection clears
- [ ] **No waveform re-render** — confirm waveform bitmap is not invalidated during any selection interaction (no visible flicker of the waveform content)
