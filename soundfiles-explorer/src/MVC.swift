//
//  MVC.swift
//  soundfiles-explorer
//
//  Created by Americo Cot on 19/1/26.
//

import Cocoa
import AVFoundation
import AVKit


// Import the custom classes
import Foundation

private enum TableColumnIdentifiers: String, CaseIterable {
    case fileName = "fileName"
    case scene = "scene"
    case take = "take"
    case takeType = "takeType"
    case tape = "tape"
    case timeCodeStart = "timeCodeStart"
    case timeCodeRate = "timeCodeRate"
    case channels = "channels"
    case circled = "circled"
    case date = "date"
    case time = "time"
    case audioDescription = "audioDescription"
    case duration = "duration"
}


class MVC: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var waveformViewPlayer: NSView!
    
    // MARK: - Variables
    private var audioPlaybackManager: AudioPlaybackManager!
    private var waveformView: AudioWaveformView!

    private var scrollView: NSScrollView!
    private var controlsStackView: NSStackView!
    private var playPauseButton: NSButton!
    private var zoomSlider: NSSlider!
    private var mainStack: NSStackView!
    private var channelLabelsContainer: NSStackView!
    private var channelLabelViews: [NSTextField] = []

    private var displayLink: CADisplayLink?
    private var audioFiles: [AudioFileInfo] = []
    private var displayedIndices: [Int] = []
    private var filterPredicate: String = ""
    private var notLoadedFiles: [String] = []
    private let metadataReader = AudioMetadataReader()
    private let audioFileLoader = AudioFileLoader()
    private var timeLabel: NSTextField!
    private var channelLabelWidth: CGFloat = 100
    
    // MARK: - Init
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.audioPlaybackManager = AudioPlaybackManager()
    }
    
    deinit {
        displayLink?.invalidate()
        removeObserver(self, forKeyPath: "AudioWaveformViewDidSeek")
        removeObserver(self, forKeyPath: "AudioPlaybackStateChanged")        
    }
    
    
    // MARK: - Overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMainView()
        setupTableView()
        setupPlayer()
        setupDisplayLink()
        setupNotifications()
        
        searchField.delegate = self
        applyFilter() // Initialize displayedIndices
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        setupLayouts()
    }
    
    // MARK: - Layouts
    func setupLayouts() {
        NSLayoutConstraint.activate([
            waveformViewPlayer.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            waveformViewPlayer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            waveformViewPlayer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            waveformViewPlayer.bottomAnchor.constraint(equalTo: searchField.topAnchor, constant: -10)
        ])
                        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: waveformViewPlayer.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: waveformViewPlayer.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: waveformViewPlayer.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: waveformViewPlayer.bottomAnchor)
        ])
        
        // Find the waveformContainer (first arranged subview of mainStack)
        guard let waveformContainer = mainStack.arrangedSubviews.first else { return }
        
        NSLayoutConstraint.activate([
            waveformContainer.topAnchor.constraint(equalTo: mainStack.topAnchor),
            waveformContainer.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            waveformContainer.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),
            controlsStackView.topAnchor.constraint(equalTo: waveformContainer.bottomAnchor),
            controlsStackView.bottomAnchor.constraint(equalTo: mainStack.bottomAnchor),
            controlsStackView.heightAnchor.constraint(equalToConstant: 48)
        ])
                                                                                        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchField.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
        
    // MARK: - Setup Views
    private func setupMainView() {
        view.frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        view.wantsLayer = true
        waveformViewPlayer.wantsLayer = true
        waveformViewPlayer.translatesAutoresizingMaskIntoConstraints = false
    }
    
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerForDraggedTypes([.fileURL])
        tableView.allowsMultipleSelection = true
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        
        // SORT DESCRIPTORS
        let fileNameSortDescriptor = NSSortDescriptor(key: TableColumnIdentifiers.fileName.rawValue,
                                                    ascending: true,
                                                    selector: #selector(NSString.localizedStandardCompare(_:)))
        if let fileNameColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: TableColumnIdentifiers.fileName.rawValue)) {
            fileNameColumn.sortDescriptorPrototype = fileNameSortDescriptor
        }
        
        let sceneSortDescriptor = NSSortDescriptor(key: TableColumnIdentifiers.scene.rawValue,
                                                   ascending: true,
                                                   selector: #selector(NSString.localizedStandardCompare(_:)))
        if let sceneColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: TableColumnIdentifiers.scene.rawValue)) {
            sceneColumn.sortDescriptorPrototype = sceneSortDescriptor
        }
        
        let takeSortDescriptor = NSSortDescriptor(key: TableColumnIdentifiers.take.rawValue,
                                                  ascending: true,
                                                  selector: #selector(NSString.localizedStandardCompare(_:)))
        if let takeColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: TableColumnIdentifiers.take.rawValue)) {
            takeColumn.sortDescriptorPrototype = takeSortDescriptor
        }
        
        let dateSortDescriptor = NSSortDescriptor(key: TableColumnIdentifiers.date.rawValue,
                                                  ascending: true,
                                                  selector: #selector(NSString.localizedStandardCompare(_:)))
        if let takeColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: TableColumnIdentifiers.date.rawValue)) {
            takeColumn.sortDescriptorPrototype = dateSortDescriptor
        }
        
        let timeCodeSortDescriptor = NSSortDescriptor(key: TableColumnIdentifiers.timeCodeStart.rawValue,
                                                   ascending: true,
                                                   selector: #selector(NSString.localizedStandardCompare(_:)))
        if let timeCodeColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: TableColumnIdentifiers.timeCodeStart.rawValue)) {
            timeCodeColumn.sortDescriptorPrototype = timeCodeSortDescriptor
        }
        
        let duartionSortDescriptor = NSSortDescriptor(key: TableColumnIdentifiers.duration.rawValue,
                                                   ascending: true,
                                                      selector: #selector(NSNumber.compare(_:)))
        if let durationColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: TableColumnIdentifiers.duration.rawValue)) {
            durationColumn.sortDescriptorPrototype = duartionSortDescriptor
        }
    }
        
    private func setupPlayer() {
        scrollView = NSScrollView()
        scrollView.wantsLayer = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
                        
        waveformView = AudioWaveformView()
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = waveformView
                
        // Setup channel labels container
        channelLabelsContainer = NSStackView()
        channelLabelsContainer.wantsLayer = true
        channelLabelsContainer.translatesAutoresizingMaskIntoConstraints = false
        channelLabelsContainer.orientation = .vertical
        channelLabelsContainer.spacing = 1
        channelLabelsContainer.widthAnchor.constraint(equalToConstant: channelLabelWidth).isActive = true
        channelLabelsContainer.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 1.0).cgColor
        channelLabelsContainer.setContentHuggingPriority(NSLayoutConstraint.Priority.required, for: .horizontal)
        channelLabelsContainer.setContentCompressionResistancePriority(NSLayoutConstraint.Priority.required, for: .horizontal)
        
        // Create horizontal stack for labels + waveform
        let waveformContainer = NSStackView()
        waveformContainer.wantsLayer = true
        waveformContainer.translatesAutoresizingMaskIntoConstraints = false
        waveformContainer.orientation = .horizontal
        waveformContainer.spacing = 1
        waveformContainer.alignment = .top
        waveformContainer.addArrangedSubview(channelLabelsContainer)
        waveformContainer.addArrangedSubview(scrollView)
        waveformContainer.layer?.borderColor = NSColor.gray.cgColor
        waveformContainer.layer?.borderWidth = 1.0
        
        setupControls()
        
        mainStack = NSStackView(frame: waveformViewPlayer.bounds)
        mainStack.wantsLayer = true
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.orientation = .vertical
        mainStack.spacing = 1
        mainStack.addArrangedSubview(waveformContainer)
        mainStack.addArrangedSubview(controlsStackView)
            
        waveformViewPlayer.addSubview(mainStack)
    }
    
    private func setupControls() {
        // Play/Pause button
        playPauseButton = NSButton(title: "▶ Play", target: self, action: #selector(playPause))
        playPauseButton.bezelStyle = .rounded
        playPauseButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
                
        // Zoom label
        let zoomLabel = NSTextField(labelWithString: "Zoom:")
        
        // Zoom slider
        zoomSlider = NSSlider(value: 100, minValue: 10, maxValue: 500, target: self, action: #selector(zoomChanged))
        zoomSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        
        // Time label
        timeLabel = NSTextField(labelWithString: "0:00.00 / 0:00.00")
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = .white
        timeLabel.widthAnchor.constraint(equalToConstant: 150).isActive = true
        
        // Create stack view for controls
        controlsStackView = NSStackView(views: [
            playPauseButton,
            NSView(), // Spacer
            zoomLabel,
            zoomSlider,
            timeLabel
        ])
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false
        controlsStackView.wantsLayer = true
        controlsStackView.orientation = .horizontal
        controlsStackView.spacing = 10
        controlsStackView.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        controlsStackView.layer?.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 1.0).cgColor
        
        // Make the spacer view expand
        let spacer = controlsStackView.arrangedSubviews[1]
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
    

    private func deleteSelectedRows() {
        let selectedIndexes = tableView.selectedRowIndexes
        // Ensure there is something to delete
        guard !selectedIndexes.isEmpty else { return }
        
        // Map displayed row indices to actual audioFiles indices
        let actualIndicesToRemove = selectedIndexes.map { displayedIndices[$0] }.sorted(by: >)
        
        // Remove from audioFiles (in descending order to maintain correct indices)
        for index in actualIndicesToRemove {
            audioFiles.remove(at: index)
        }
        
        // Re-apply filter to update displayedIndices
        applyFilter()
        
        let selectRow = min(selectedIndexes.first!, displayedIndices.count - 1)
        tableView.reloadData()
        if displayedIndices.count > 0 {
            tableView.selectRowIndexes(IndexSet([max(0, selectRow)]), byExtendingSelection: false)
        }
    }

    
    func controlTextDidChange(_ obj: Notification) {
        guard obj.object as? NSSearchField == searchField else { return }
        filterPredicate = searchField.stringValue
        applyFilter()
        tableView.reloadData()
    }
    
    private func applyFilter() {
        if filterPredicate.isEmpty {
            displayedIndices = Array(0..<audioFiles.count)
        } else {
            displayedIndices = audioFiles.enumerated()
                .filter { $0.element.scene.localizedCaseInsensitiveContains(filterPredicate) }
                .map { $0.offset }
        }
    }
        
    
    
    // MARK: - NSTableViewDataSource methods
    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedIndices.count
    }
    
    private func audioFileAt(row: Int) -> AudioFileInfo {
        return audioFiles[displayedIndices[row]]
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let colIdentifier = tableColumn?.identifier else { return nil }
        let audioFile = audioFileAt(row: row)
        
        switch TableColumnIdentifiers(rawValue: colIdentifier.rawValue) {
        case .fileName:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFile.fileName)"
            return viewCell
        case .scene:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFile.ixml?.scene ?? "")"
            return viewCell
        case .take:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFile.ixml?.take ?? "")"
            return viewCell
        case .takeType:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFile.ixml?.parsedData["TAKE_TYPE"] ?? "")"
            return viewCell
        case .tape:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFile.ixml?.parsedData["TAPE"] ?? "")"
            return viewCell
        case .timeCodeStart:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = audioFile.timeCodeStart
            return viewCell
        case .timeCodeRate:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            let tcr = evaluateTimeCodeRate(expressionString: audioFile.ixml?.parsedData["TIMECODE_RATE"] ?? "0")
            viewCell.textField!.stringValue = "\(tcr) \(audioFile.ixml?.parsedData["TIMECODE_FLAG"] ?? "")"
            return viewCell
        case .channels:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFile.channelCount)"
            return viewCell
        case .circled:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            if let circled = audioFile.ixml?.parsedData["CIRCLED"] {
                switch circled.lowercased() {
                case "true":
                    viewCell.textField!.stringValue = "√"
                default:
                    viewCell.textField!.stringValue = ""
                }
            }
            return viewCell
        case .date:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFile.bext?.originationDate ?? "")"
            return viewCell
        case .time:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFile.bext?.originationTime ?? "")"
            return viewCell
        case .audioDescription:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFile.bitDepth)b \(audioFile.sampleRate)Hz"
            return viewCell
        case .duration:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            let audioLength = formatTime(audioFile.duration)
            viewCell.textField!.stringValue = "\(audioLength)"
            return viewCell
        default:
            return nil
        }
    }
    
    // MARK: - TableView Delegate Methods
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        let selectedRow = tableView.selectedRow
        if selectedRow != -1 && selectedRow < displayedIndices.count {
            if audioPlaybackManager.isPlaying {
                audioPlaybackManager.pause()
            }
            
            let actualIndex = displayedIndices[selectedRow]
            
            Task {
                let fileInfo = audioFiles[actualIndex]
                // Update waveform view with pre-generated data
                waveformView.setWaveformData(fileInfo.waveformData,
                                             duration: fileInfo.duration,
                                             sampleRate: fileInfo.sampleRate,
                                             channelCount: fileInfo.channelCount,
                                             names: fileInfo.tracksNames
                )
                                                                
                // Update channel labels
                setupChannelLabels()
                
                // Update playback manager with player item
                audioPlaybackManager.setPlayerItem(fileInfo.playerItem, duration: Float64(fileInfo.duration))
            }
        }
                                                                    
            #if DEBUG
            // print("\nFILE DESCRIPTION START")
            // print("BEXT: \(String(describing: audioFiles[actualIndex].bext))\n")
            // print("iXML(parsedData): \(String(describing: audioFiles[actualIndex].ixml?.parsedData))")
            // print("iXML(rawData): \(audioFiles[actualIndex].ixml?.rawXML ?? "")")
            // print("FILE DESCRIPTION END\n")
            #endif
        
    }
    
    
    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation
    {
        if info.draggingSource as? NSTableView == tableView {
            // Internal move (row reordering)
            tableView.setDropRow(row, dropOperation: .above)
            return .move
        } else if info.draggingPasteboard.types?.contains(.fileURL) == true {
            // File Drop (from Finder)
            tableView.setDropRow(row, dropOperation: .above)
            return .copy
        }
        return []
    }
    
    
        
    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool
    {
        // Moved row on tableview
        if info.draggingSource as? NSTableView == tableView {
            // Disable internal reordering when filtering is active
            guard filterPredicate.isEmpty else { return false }
            
            guard let sourceRow = tableView.selectedRowIndexes.first else {
                return false
            }
            
            guard sourceRow != row else {
                return false
            } // Prevent dropping onto the same row
            
            let draggedItem = audioFiles[sourceRow]
            audioFiles.remove(at: sourceRow)
            
            // Adjust the destination index when dragging downwards
            let adjustedIndex = row > sourceRow ? row - 1 : row
            audioFiles.insert(draggedItem, at: adjustedIndex)
            tableView.moveRow(at: sourceRow, to: adjustedIndex)
            return true
        // Dragged files from finder
        } else if info.draggingPasteboard.types?.contains(.fileURL) == true {
            guard let pasteboardObjects = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil),
                  pasteboardObjects.count > 0 else {
                return false
            }
            notLoadedFiles.removeAll()
            pasteboardObjects.forEach { (object) in
                if let url = object as? URL {
                Task {
                    do {
                        let fileInfo = try await audioFileLoader.loadAudioFile(url)
                        self.audioFiles.append(fileInfo)
                        await MainActor.run {
                            self.applyFilter()
                            self.tableView.reloadData()
                        }
                    } catch {
                        self.notLoadedFiles.append(url.lastPathComponent)
                    }
                }
                }
            }
                        
            if notLoadedFiles.count > 0 {
                let alert = NSAlert()
                alert.messageText = "Some files could not be loaded."
                alert.informativeText = notLoadedFiles.joined(separator: ", ")
                alert.runModal()
            }
            return true
        }
        return false
    }

    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        let sortedArray = NSMutableArray(array: audioFiles)
        sortedArray.sort(using: tableView.sortDescriptors)
        audioFiles = sortedArray as! [AudioFileInfo]
        applyFilter() // Re-apply filter after sorting
        tableView.reloadData()
    }

    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting?
    {
        return audioFileAt(row: row).url as NSURL? ?? NSURL()
    }
        

    // MARK: - Keyboard event handlers
    override func keyDown(with event: NSEvent) {
        print("Key Event:\(event)")
            switch event.keyCode {
            case 51, 117:
                deleteSelectedRows()
            case 40, 49: // K or Space Bar
                playPause()
                break
            case 38: // J
                playRewind()
                break
            case 37: // L
                playForward()
                break
            case 36: // Return
                stopAndGoStartEnd(event.modifierFlags)
                break
            /// Zoom
            case 15: // R
                zoomSlider.doubleValue = zoomSlider.doubleValue * 0.75
                waveformView.setZoomLevel(zoomSlider.doubleValue)
                break
            case 17: // T
                zoomSlider.doubleValue = zoomSlider.doubleValue * 1.25
                waveformView.setZoomLevel(zoomSlider.doubleValue)
                break
            default:
                super.keyDown(with: event)
            }
    }
    
    
    @objc private func playPause() {
        // AVAudioPlayer
        if waveformView.isPlaying {
            audioPlaybackManager.pause()
            playPauseButton.title = "▶ Play"
            waveformView.isPlaying = false
        } else {
            audioPlaybackManager.play()
            playPauseButton.title = "⏸ Pause"
            waveformView.isPlaying = true
        }
    }
    
    @objc private func playRewind() {
        // guard let player = audioPlayer else { return }
        audioPlaybackManager.setRate(audioPlaybackManager.rate - 1.5)
        audioPlaybackManager.isPlaying = true
        waveformView.isPlaying = true
    }
    
    @objc private func playForward() {
        // guard let player = audioPlayer else { return }
        audioPlaybackManager.setRate(audioPlaybackManager.rate + 1.5)
        audioPlaybackManager.isPlaying = true
        waveformView.isPlaying = true
    }
    

    @objc private func stopAndGoStartEnd(_ modifier: NSEvent.ModifierFlags) {
        audioPlaybackManager.pause()
        waveformView.isPlaying = false
        audioPlaybackManager.isPlaying = false
        let destTime = (modifier.rawValue != 262401) ? 0.0 : audioPlaybackManager.duration
        audioPlaybackManager.seek(to: destTime)
        waveformView.currentTime = destTime
        
        let visibleRect = scrollView.documentVisibleRect
        let newX = destTime <= 0 ? 0.0 : destTime * waveformView.pixelsPerSecond
        scrollView.contentView.scroll(to: NSPoint(x: newX, y: visibleRect.minY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        updatePlaybackPosition()
    }

    
    //MARK: - Helpers Functions
    func timecodeFromTimeReference(samples: Int64, sampleRate: Double, frameRate: Double) -> String {
        // Convert samples to seconds
        let seconds = Double(samples) / sampleRate
        
        // Convert seconds to timecode components
        let totalFrames = Int64(seconds * frameRate)
        let frames = totalFrames % Int64(frameRate)
        let secondsTotal = totalFrames / Int64(frameRate)
        let secs = secondsTotal % 60
        let mins = (secondsTotal / 60) % 60
        let hours = secondsTotal / 3600
        
        return String(format: "%02d:%02d:%02d:%02d", hours, mins, secs, frames)
    }

    
    func audioFormatFromCodingHistory(_ codingHistory: String) -> String {
        if codingHistory.isEmpty { return "Unknown" }
        var algorithm: String = ""
        var sampleRate: String = ""
        var bitDepth: String = ""
        let lines = codingHistory.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ",")
        for line in lines {
            let splitedLine = line.split(separator: "=")
            switch line.first {
            case "A":
                algorithm = String(splitedLine[1])
                break
            case "F":
                sampleRate = String(splitedLine[1])
                break
            case "W":
                bitDepth = String(splitedLine[1])
                break
            default:
                break
            }
        }
            
        let result: String = "\(bitDepth)bits \(sampleRate)Hz \(algorithm)"
        return result
    }
    
    
    func evaluateTimeCodeRate(expressionString: String) -> String {
        // Replace integers with floating-point literals (e.g., "25" → "25.0")
        let formattedString = expressionString
            .replacingOccurrences(of: "\\b\\d+\\b", with: "$0.0", options: .regularExpression)
        
        let expression = NSExpression(format: formattedString)
        if let result = expression.expressionValue(with: nil, context: nil) as? Float {
            return String(format: "%.10g", result) // Avoid trailing zeros
        } else {
            // return default values
            return "00:00:00:00"
        }
    }
    
    
    // MARK: - Methods
    private func setupDisplayLink() {
        displayLink = self.waveformView.displayLink(target: self, selector: #selector(updatePlaybackPosition))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 1/60.0, maximum: 1/30.0, preferred: 1/30.0)
        displayLink?.isPaused = true
        displayLink?.add(to: .main, forMode: .common)
    }
 
    // private var lastUpdateTime: CFTimeInterval = 0
    // private let updateInterval: CFTimeInterval = 1.0 / 30.0 // Update at 30fps max
    
    @objc private func updatePlaybackPosition() {
        // let currentTime = CACurrentMediaTime()
        // Rate limit updates to prevent excessive CPU usage
        // if currentTime - lastUpdateTime < updateInterval { return }
        // lastUpdateTime = currentTime
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.waveformView.currentTime = audioPlaybackManager.getCurrentTime()
            self.updateTimeLabel()
            self.scrollToFollowPlayback()
        }
    }
    
    private func scrollToFollowPlayback() {
        let visibleRect = scrollView.documentVisibleRect
        let cursorX = CGFloat(audioPlaybackManager.currentTime) * waveformView.pixelsPerSecond
        
        // Scroll if cursor is near the edges or outside visible area
        let scrollMargin: CGFloat = 100
        let needsScroll = cursorX < visibleRect.minX + scrollMargin ||
                         cursorX > visibleRect.maxX - scrollMargin
        
        if needsScroll {
            let newX = max(0, cursorX - visibleRect.width / 2)
            scrollView.contentView.scroll(to: NSPoint(x: newX, y: visibleRect.minY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
    
    
    
    private func updateTimeLabel() {
        guard let audioPlaybackManager else {
            timeLabel.stringValue = "0:00.00 / 0:00.00"
            return
        }
                
        let current = formatTime(audioPlaybackManager.currentTime)
        let total = formatTime(audioPlaybackManager.duration)        
        
        timeLabel.stringValue = "\(current) / \(total)"
    }
        
            
    @objc private func zoomChanged() {
        waveformView.setZoomLevel(CGFloat(zoomSlider.doubleValue))
        waveformView.updateContentSize()
    }
    
    @objc private func waveformViewDidSeek(_ notification: Notification) {
        guard let time = (notification.userInfo?["time"] as? TimeInterval) else { return }
        audioPlaybackManager.seek(to: time)
        
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(waveformViewDidSeek(_:)),
            name: NSNotification.Name("AudioWaveformViewDidSeek"),
            object: waveformView
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged(_:)),
            name: NSNotification.Name("AudioPlaybackStateChanged"),
            object: audioPlaybackManager
        )
    }
    
    @objc private func playbackStateChanged(_ notification: Notification) {
        guard let isPlaying = notification.userInfo?["isPlaying"] as? Bool else { return }
        displayLink?.isPaused = !isPlaying
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time >= 0 else { return "--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    // MARK: - Channel Labels
    
    /// Creates and updates channel labels in the fixed container view
    private func setupChannelLabels() {
        // Remove existing labels from stack view properly
        channelLabelViews.forEach {
            channelLabelsContainer.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        channelLabelViews.removeAll()
        
        // Get channel info from waveform view
        let channelNames = waveformView.channelNames
        let channelHeight = waveformView.channelHeight
        let channelSpacing = CGFloat(1) // Match AudioWaveformView
        
        guard !channelNames.isEmpty else { return }
        
        // Create labels for each channel
        for (_, channelName) in channelNames.enumerated() {
            let label = NSTextField(labelWithString: channelName)
            label.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            label.textColor = NSColor.white
            label.alignment = NSTextAlignment.left
            label.isEditable = false
            label.isBordered = true
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentHuggingPriority(NSLayoutConstraint.Priority.required, for: NSLayoutConstraint.Orientation.vertical)
            label.setContentCompressionResistancePriority(NSLayoutConstraint.Priority.required, for: NSLayoutConstraint.Orientation.vertical)
            
            // Add height constraint
            label.heightAnchor.constraint(equalToConstant: channelHeight).isActive = true
            label.widthAnchor.constraint(equalToConstant: channelLabelWidth).isActive = true
            
            channelLabelViews.append(label)
            channelLabelsContainer.addArrangedSubview(label)
        }
        
        // Set container spacing to match waveform view
        channelLabelsContainer.spacing = channelSpacing
        
        // Set distribution to fill from top
        channelLabelsContainer.distribution = .fill
        channelLabelsContainer.alignment = .leading
        
        // Set hugging priority to prevent stretching in parent horizontal stack view
        channelLabelsContainer.setContentHuggingPriority(NSLayoutConstraint.Priority.required, for: NSLayoutConstraint.Orientation.vertical)
        channelLabelsContainer.setContentCompressionResistancePriority(NSLayoutConstraint.Priority.required, for: NSLayoutConstraint.Orientation.vertical)
        
        // Force layout update
        channelLabelsContainer.needsLayout = true
        channelLabelsContainer.needsDisplay = true
    }
}
