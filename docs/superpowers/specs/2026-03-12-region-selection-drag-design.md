# Region Selection & Drag-to-DAW — Design Spec
**Date:** 2026-03-12
**Status:** Approved
**Scope:** Phase 1 (Region Selection) + Phase 2 (Drag to External App)

---

## Problem & Intent

Users need to select a sub-region of an audio file in the waveform view and drag that region directly into a DAW (Pro Tools, Logic, Reaper, Finder, etc.). This avoids exporting the whole file when only a clip is needed.

---

## Visual Design

**Style: Dim-outside / bright-inside (Pro Tools-inspired)**

- Everything outside the selection is overlaid with a dark translucent rect (`rgba(0,0,0,0.5)`)
- The selected region is bounded by a white border (1.5pt)
- White pill-shaped handles sit at the vertical mid-point of each edge (for resize)
- A floating duration badge appears inside the selection (amber tint while resizing, translucent white otherwise)
- All layer updates are zero-cost (no waveform bitmap re-render)

---

## Architecture

### Layer Stack (additions to existing stack)

| Layer | z-position | Purpose |
|---|---|---|
| `waveformLayer` | 10 | Existing: static bitmap (untouched) |
| `leftDimLayer` | 20 | Dark overlay left of selection |
| `rightDimLayer` | 21 | Dark overlay right of selection |
| `selectionBorderLayer` | 22 | White `CALayer` border (1.5pt) |
| `leftHandleLayer` | 23 | Left edge resize grip |
| `rightHandleLayer` | 24 | Right edge resize grip |
| `durationBadgeLayer` | 25 | `CATextLayer` showing selection duration |
| `cursorLayer` | 50 | Existing: red playhead (untouched) |

All dim/border/handle layers are hidden when no selection is active.

### Selection State

```swift
// In AudioWaveformView
private(set) var selectionRegion: (start: TimeInterval, end: TimeInterval)? {
    didSet { updateSelectionLayers() }
}
```

`updateSelectionLayers()` recomputes all 6 layer frames and the badge text in one pass. It is the only path that modifies selection layer geometry — no layout happens inside mouse handlers.

`selectionRegion` must be reset to `nil` whenever new waveform data is loaded. `setWaveformData(...)`, `clearWaveform()`, and `showLoadingState(...)` must all call `selectionRegion = nil`. This prevents a stale region from a previous file (with a different duration) being inherited by the next file.

`updateSelectionLayers()` must also be called from the `pixelsPerSecond` `didSet` observer (alongside the existing `needsWaveformUpdate = true` call), so that selection layer frames recompute correctly when the user changes zoom level.

### Mouse Interaction State Machine

```swift
private enum DragState {
    case idle
    case draggingNewSelection(anchorTime: TimeInterval)
    case resizingLeft(originalEnd: TimeInterval)
    case resizingRight(originalStart: TimeInterval)
}
private var dragState: DragState = .idle
```

**`mouseDown(with:)`**
1. Convert click to `TimeInterval` via `x / pixelsPerSecond`
2. If within ±8px of left handle → `.resizingLeft` (return early — no seek)
3. If within ±8px of right handle → `.resizingRight` (return early — no seek)
4. If inside existing selection → `selectionRegion = nil`, enter `.idle`, return early — **do not post `AudioWaveformViewDidSeek`** (no seek)
5. Otherwise → clear any existing selection, start `.draggingNewSelection(anchorTime: clickedTime)`, return early — no seek while dragging
6. The existing seek notification (`AudioWaveformViewDidSeek`) is posted **only** when none of the above early-return branches fire — i.e., plain click on empty waveform with no active selection

This ordering is critical: deselect/resize/drag branches must all return before the seek path.

**`mouseDragged(with:)`**
- `.draggingNewSelection`: `selectionRegion = (min(anchor, now), max(anchor, now))`
- `.resizingLeft`: `selectionRegion = (now, originalEnd)`, swap if crossed
- `.resizingRight`: `selectionRegion = (originalStart, now)`, swap if crossed

**`mouseUp(with:)`**
- If region duration < 0.05s → discard (too small, likely a mis-click)
- Otherwise normalize: ensure start < end
- Set `dragState = .idle`

**Cursor updates**
- Override `updateTrackingAreas()` (the correct lifecycle hook — called on view resize) to remove the old tracking area and add a new one covering the full view bounds (`.mouseMoved` + `.cursorUpdate` + `.activeInKeyWindow`). Also call `super.updateTrackingAreas()`. Do **not** add the tracking area only in `init` — the view's frame changes when `pixelsPerSecond` changes (it drives `intrinsicContentSize`).
- `mouseMoved`: hit-test edge zones, push `NSCursor.resizeLeftRight` or restore default
- `cursorUpdate`: same logic

---

## Playback Integration (MVC.swift)

In `updatePlaybackPosition()` (CADisplayLink callback), add after updating `waveformView.currentTime`:

```swift
if let region = waveformView.selectionRegion,
   audioPlaybackManager.isPlaying,
   audioPlaybackManager.getCurrentTimeDirect() >= region.end {
    audioPlaybackManager.pause()
    // pause() posts AudioPlaybackStateChanged which will pause the display link
    // on the next tick; guard isPlaying above prevents a double-pause
}
```

No changes to `AudioPlaybackManager` itself. Note: the display link is paused by the `AudioPlaybackStateChanged` handler, so the check naturally stops firing once paused — the `isPlaying` guard prevents a redundant second call on any intermediate tick.

---

## Notification

Add a new notification for the controller to react to selection changes (e.g., to update a status bar or enable/disable export button in future):

| Name | Direction | Payload |
|---|---|---|
| `AudioWaveformViewSelectionChanged` | View → Controller | `["start": TimeInterval, "end": TimeInterval]` or nil userInfo for deselect |

---

## Files to Modify

| File | Changes |
|---|---|
| `Views/AudioWaveformView.swift` | Add 6 selection layers, `selectionRegion` property, `DragState` enum, mouse handlers, tracking area, `updateSelectionLayers()` |
| `src/MVC.swift` | Add region-end playback stop in CADisplayLink callback; observe `AudioWaveformViewSelectionChanged` for future use |

`Views/AudioWaveformExtensions.swift` — no changes needed; the existing `WaveformRegion` class there is disconnected and will not be used (it renders into the static bitmap, which is too slow for interactive use).

---

## Phase 2: Drag to External App (separate implementation cycle)

When a region is finalized, dragging from inside the selection initiates a system drag:

1. Detect drag threshold (~4pt) inside `mouseDragged` when `dragState == .idle` and a region exists. Note: the Phase 2 spec must introduce a `.potentialDragFromSelection` drag state so that `mouseDown` inside a finalized selection does **not** clear the selection before the drag threshold can be evaluated — instead it parks in that intermediate state and only clears on `mouseUp` if no drag threshold was crossed.
2. Slice audio: read `channelWaveforms: [[Float]]` for the region's time range, write a PCM WAV file to a temp path (`FileManager.default.temporaryDirectory`)
3. Create `NSDraggingItem` with the file URL
4. Call `beginDraggingSession(with:event:source:)` — `AudioWaveformView` conforms to `NSDraggingSource`
5. Drag image: render a small waveform thumbnail of the selected region

This is a separate spec + plan cycle.

---

## Verification

- **Selection draw**: drag in waveform → dim layers appear outside, white border inside
- **Edge resize**: hover near edge → cursor changes; drag → region trims live
- **Discard tiny selection**: click without dragging (or very short drag) → no region created
- **Deselect**: click outside selection → selection clears
- **Playback stop**: with region selected, press play → playback stops at region end
- **Scroll**: with region selected, scroll/zoom → layers reposition correctly (they follow `pixelsPerSecond`)
- **No waveform re-render**: confirm waveform bitmap is not invalidated during any selection interaction
