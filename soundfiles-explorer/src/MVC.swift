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

private class AudioFile: NSObject {
    @objc let fileName: String
    @objc var scene: String
    @objc var take: String
    @objc var timeCodeStart: String
    let url: URL
    let chCount: Int
    let bitDepth: Int
    let sampleRate: Int
    let trackNames: [String: String] = [:]
    let bext: BEXTMetadata?
    let ixml: IXMLMetadata?
    
    init(fileName: String,
         scene: String = "",
         take: String = "",
         timeCodeStart: String = "",
         url: URL, chCount: Int,
         bitDepth: Int,
         sampleRate: Int,
         trackNames: [String: String] = [:],
         bext: BEXTMetadata?,
         ixml: IXMLMetadata?
    ) {
        self.fileName = fileName
        self.scene = scene
        self.take = take
        self.url = url
        self.chCount = chCount
        self.bitDepth = bitDepth
        self.sampleRate = sampleRate
        self.bext = bext
        self.ixml = ixml
        self.timeCodeStart = timeCodeStart
        super.init()
    }
}

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
}


class MVC: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var searchField: NSSearchField!
    // @IBOutlet weak var playerView: AVPlayerView!
    @IBOutlet weak var waveformViewPlayer: NSView!
    
    // MARK: - Variables
    private var audioPlaybackManager: AudioPlaybackManager!
    private var waveformView: AudioWaveformView!
    private var scrollView: NSScrollView!
    private var controlsStackView: NSStackView!
    private var playPauseButton: NSButton!
    private var zoomSlider: NSSlider!
    private var mainStack: NSStackView!


    private var displayLink: CVDisplayLink?
    private var audioFiles: [AudioFile] = []
    private var backupAudioFiles: [AudioFile] = []
    private var notLoadedFiles: [String] = []
    private let metadataReader = AudioMetadataReader()
    private var timeLabel: NSTextField!
    private var currentAudioDuration: CMTime = .zero
    
    
    // MARK: - Init
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.audioPlaybackManager = AudioPlaybackManager()
    }
    
    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
    
    
    // MARK: - Overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupPlayer()
        searchField.delegate = self
        setupDisplayLink()
        setupNotifications()
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return event // Return the event to allow normal processing
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        setupLayouts()
    }
    
    // MARK: - Layouts
    func setupLayouts() {
        NSLayoutConstraint.activate([
            waveformViewPlayer.topAnchor.constraint(equalTo: view.topAnchor),
            waveformViewPlayer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            waveformViewPlayer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            waveformViewPlayer.bottomAnchor.constraint(equalTo: searchField.topAnchor)
        ])
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: waveformViewPlayer.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: waveformViewPlayer.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: waveformViewPlayer.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: waveformViewPlayer.bottomAnchor),
            controlsStackView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: mainStack.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor)
        ])
        
        if let dv = scrollView.documentView {
            NSLayoutConstraint.activate([
                dv.topAnchor.constraint(equalTo: scrollView.topAnchor),
                dv.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
            ])
        }
    }
    
        
    // MARK: - Setup Views
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
        
        let timeCodeSortDescriptor = NSSortDescriptor(key: TableColumnIdentifiers.timeCodeStart.rawValue,
                                                   ascending: true,
                                                   selector: #selector(NSString.localizedStandardCompare(_:)))
        if let timeCodeColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: TableColumnIdentifiers.timeCodeStart.rawValue)) {
            timeCodeColumn.sortDescriptorPrototype = timeCodeSortDescriptor
        }
        
    }
    
    private func setupPlayer() {
        // self.player = AVPlayer()
        // self.playerView.player = self.player
        // self.playerView.controlsStyle = .inline
                
        // AVAudioPlayer
        self.mainStack = NSStackView(frame: waveformViewPlayer.bounds)
        let scrollViewRect = NSRect(origin: CGPoint(x: waveformViewPlayer.bounds.width,
                                                   y: waveformViewPlayer.bounds.height + 60.0),
                                    size: CGSize(width: waveformViewPlayer.bounds.width,
                                                 height: waveformViewPlayer.bounds.height - 60.0)
        )
        
        scrollView = NSScrollView(frame: scrollViewRect)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 1.0)
        
        waveformView = AudioWaveformView(frame: scrollView.bounds)
        scrollView.documentView = waveformView
        scrollView.documentView?.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        waveformViewPlayer.addSubview(mainStack)
                
        setupControls()
                                
        mainStack.orientation = .vertical
        mainStack.spacing = 0
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(scrollView)
        mainStack.addArrangedSubview(controlsStackView)
                                                                            
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
        controlsStackView.orientation = .horizontal
        controlsStackView.spacing = 10
        controlsStackView.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        controlsStackView.wantsLayer = true
        controlsStackView.layer?.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 1.0).cgColor
        
        // Make the spacer view expand
        let spacer = controlsStackView.arrangedSubviews[2]
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
    }
    

    private func deleteSelectedRows() {
        let selectedIndexes = tableView.selectedRowIndexes
        // Ensure there is something to delete
        guard selectedIndexes.isEmpty else { return }
        
        // Convert to an array and delete items from the data source
        let indexesToRemove = selectedIndexes.sorted(by: >) // Sort in descending order
        print(indexesToRemove)
        for index in indexesToRemove {
            audioFiles.remove(at: index)
        }
        
        let selectRow = indexesToRemove.endIndex - 1
        tableView.removeRows(at: selectedIndexes, withAnimation: .effectFade)
        tableView.selectRowIndexes(IndexSet([selectRow]), byExtendingSelection: false)
    }

    
    func controlTextDidChange(_ obj: Notification) {
        guard obj.object as? NSSearchField == searchField else { return }
        if searchField.stringValue.isEmpty {
            audioFiles = backupAudioFiles
            tableView.reloadData()
        } else {
            audioFiles = audioFiles.filter { $0.scene.localizedCaseInsensitiveContains(searchField.stringValue) }
            tableView.reloadData()
        }
    }
    
    
    // MARK: - NSTableViewDataSource methods
    func numberOfRows(in tableView: NSTableView) -> Int {
        audioFiles.count
    }
    
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let colIdentifier = tableColumn?.identifier else { return nil }
        switch TableColumnIdentifiers(rawValue: colIdentifier.rawValue) {
        case .fileName:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].fileName)"
            return viewCell
        case .scene:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml?.scene ?? "")"
            return viewCell
        case .take:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml?.take ?? "")"
            return viewCell
        case .takeType:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml?.parsedData["TAKE_TYPE"] ?? "")"
            return viewCell
        case .tape:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml?.parsedData["TAPE"] ?? "")"
            return viewCell
        case .timeCodeStart:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = audioFiles[row].timeCodeStart
            return viewCell
        case .timeCodeRate:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            let tcr = evaluateTimeCodeRate(expressionString: audioFiles[row].ixml?.parsedData["TIMECODE_RATE"] ?? "0")
            viewCell.textField!.stringValue = "\(tcr) \(audioFiles[row].ixml?.parsedData["TIMECODE_FLAG"] ?? "")"
            return viewCell
        case .channels:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            // viewCell.textField!.stringValue = "\(audioFiles[row].ixml?.parsedData["TRACK_COUNT"] ?? "")"
            viewCell.textField!.stringValue = "\(audioFiles[row].chCount)"
            return viewCell
        case .circled:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            if let circled = audioFiles[row].ixml?.parsedData["CIRCLED"] {
                switch circled.lowercased() {
                case "true":
                    viewCell.textField!.stringValue = "√"
                    break
                default:
                    viewCell.textField!.stringValue = ""
                }
            }
            return viewCell
        case .date:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].bext?.originationDate ?? "")"
            return viewCell
        case .time:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].bext?.originationTime ?? "")"
            return viewCell
        case .audioDescription:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].bitDepth)b \(audioFiles[row].sampleRate)Hz"
            return viewCell
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation == .copy {
            print("Copy audioFiles to backp")
            backupAudioFiles.append(contentsOf: audioFiles)
        }
    }
    
    
    // MARK: - TableView Delegate Methods
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        let selectedRow = tableView.selectedRow
        if selectedRow != -1 {
            if audioPlaybackManager.isPlaying {
                audioPlaybackManager.pause()
            }
            
            // let playerItem = AVPlayerItem(url: audioFiles[selectedRow].url)
            // self.player.replaceCurrentItem(with: playerItem)
            
            // Load audioFile to AVAudioPlayer and update waveforms
            audioPlaybackManager.loadAudioFile(audioFiles[selectedRow].url)
            waveformView.audioURL = audioFiles[selectedRow].url
            
            // print("SIZE: \(waveformView.frame.size)")
            scrollView.documentView?.setFrameSize(waveformView.bounds.size)
            scrollView.needsDisplay = true
            currentAudioDuration = CMTime(seconds: audioPlaybackManager.duration, preferredTimescale: 1)
            
                                                
            #if DEBUG
            // print("\nFILE DESCRIPTION START")
            // print("BEXT: \(String(describing: audioFiles[selectedRow].bext))\n")
            // print("iXML(parsedData): \(String(describing: audioFiles[selectedRow].ixml?.parsedData))")
            // print("iXML(rawData): \(audioFiles[selectedRow].ixml?.rawXML ?? "")")
            // print("FILE DESCRIPTION END\n")
            #endif
        }
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
                    do {
                        let data = try metadataReader.readAudioMetadata(from: url)
                        let row = metadataReader.extractTableViewRows(from: data)
                        for r in row {
                            print("\(r.category)::\t\(r.field) : \(r.value)")
                        }
                        Task {
                            let asbd = try await loadAudioBasicDescription(for: url)
                            let audioFile = AudioFile(fileName: url.deletingPathExtension().lastPathComponent,
                                                      url: url,
                                                      chCount: Int(asbd.mChannelsPerFrame),
                                                      bitDepth: Int(asbd.mBitsPerChannel),
                                                      sampleRate: Int(asbd.mSampleRate),
                                                      bext: data.bext,
                                                      ixml: data.ixml)
                            
                            if let ixml = audioFile.ixml, let bext = audioFile.bext {
                                if let sc = ixml.scene {
                                    audioFile.scene = sc
                                }
                                if let take = ixml.take {
                                    audioFile.take = take
                                }
                                
                                let tcr = ixml.parsedData["TIMECODE_RATE"]!.split(separator: "/")
                                audioFile.timeCodeStart = timecodeFromTimeReference(samples: Int64(bext.timeReferenceSamples),
                                                                               sampleRate: Double(audioFile.sampleRate),
                                                                               frameRate: Double(tcr[0])!
                                )
                            }
                            
                            self.audioFiles.append(audioFile)
                            await MainActor.run {
                                    tableView.reloadData()
                            }
                        }
                    } catch {
                        self.notLoadedFiles.append(url.lastPathComponent)
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
        audioFiles = sortedArray as! [AudioFile]
        tableView.reloadData()
    }

    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting?
    {
        return audioFiles[row].url as NSURL
    }
        

    // MARK: - Keyboard event handlers
    override func keyDown(with event: NSEvent) {
        print("Key Event:\(event)")
        switch event.modifierFlags {
        case .command:
            print("Command Key")
            switch event.keyCode {
            case 36: // Return
                // stopAndGoStartEnd(event.modifierFlags)
                break
            default:
                super.keyDown(with: event)
            }
        case .control:
            switch event.keyCode {
            case 36: // Return
                // stopAndGoStartEnd(event.modifierFlags)
                break
            default:
                super.keyDown(with: event)
            }
            
        
        default:
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
                // stopAndGoStartEnd(event.modifierFlags)
                break
            default:
                super.keyDown(with: event)
            }
            break
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
        waveformView.isPlaying = true
    }
    
    @objc private func playForward() {
        // guard let player = audioPlayer else { return }
        audioPlaybackManager.setRate(audioPlaybackManager.rate + 1.5)
        waveformView.isPlaying = true
    }
    
/*
    @objc private func stopAndGoStartEnd(_ modifier: NSEvent.ModifierFlags) {
        // guard let player = audioPlayer else { return }
        // player.stop()
        let destTime = (modifier.rawValue != 262401) ? CMTime(seconds: 0.0, preferredTimescale: 1)
                                            : CMTime(seconds: currentAudioDuration.seconds, preferredTimescale: 1)
        
        audioPlaybackManager.seek(to: CMTimeGetSeconds(destTime)) { [weak self] finished in
            DispatchQueue.main.async {
                if finished {
                    player.pause()
                    self?.waveformView.isPlaying = false
                    print("Seek to \(destTime) seconds completed successfully.")
                } else {
                    print("Seek operation was interrupted.")
                    
                }
                // Perform any UI updates or follow-up actions here
                self?.scrollToFollowPlayback()
            }
        }
                
    }
*/
    
    //MARK: - Helpers Functions
    func loadAudioBasicDescription(for url: URL) async throws -> AudioStreamBasicDescription {
          let loadOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
          let asset = AVURLAsset(url: url, options: loadOptions)

          guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
              throw AudioParserError.noAudioTrack
          }

          guard let asbd = try await track.load(.formatDescriptions).first?.audioFormatList.first?.mASBD else {
              throw AudioParserError.malformedMetadata
          }
          return asbd
      }

    
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
    
    
    // MARK: - AVAudioPlayer Methods
/*
    func loadAudioURL(_ url: URL) {
        // Setup audio player
        do {
            // audioPlayer = try AVAudioPlayer(contentsOf: url)
            // audioPlayer?.prepareToPlay()
            // audioPlayer?.volume = 1.0
            // audioPlayer?.enableRate = true
            let asset = AVAsset(url: url)
            let item = AVPlayerItem(asset: asset)
            // self.audioPlayer.replaceCurrentItem(with: item)
            self.currentAudioDuration = item.duration
            
            // You can customize channel names based on your audio file
            // For example, if you know the file has specific channels:
            // waveformView.setChannelNames(["Boom Mic", "Lav 1", "Lav 2", "Ambient"])
            
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error Loading Audio"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
*/
    
    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
                let controller = Unmanaged<MVC>.fromOpaque(displayLinkContext!).takeUnretainedValue()
                controller.updatePlaybackPosition()
                return kCVReturnSuccess
            }, Unmanaged.passUnretained(self).toOpaque())
            CVDisplayLinkStart(displayLink)
        }
    }
 
    private var lastUpdateTime: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 1.0 / 30.0 // Update at 30fps max

    private func updatePlaybackPosition() {
        let currentTime = CACurrentMediaTime()

        // Rate limit updates to prevent excessive CPU usage
        if currentTime - lastUpdateTime < updateInterval {
            return
        }

        lastUpdateTime = currentTime

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // self.waveformView.currentTime = player.currentTime
            self.waveformView.currentTime = audioPlaybackManager.currentTime //player.currentItem?.currentTime().seconds ?? 0
            self.updateTimeLabel()

            // Auto-scroll to follow playback
            // if player.isPlaying {
            //     self.scrollToFollowPlayback()
            // }
            if audioPlaybackManager.rate != 0 {
                self.scrollToFollowPlayback()
            }
        }
    }
    
    private func updateTimeLabel() {
        // guard let player = audioPlayer else {
        //     timeLabel.stringValue = "0:00.00 / 0:00.00"
        //     return
        // }
        
        // let current = formatTime(player.currentTime)
        // let total = formatTime(player.duration)
        let current = formatTime(audioPlaybackManager.currentTime)
        let total = formatTime(audioPlaybackManager.duration)
        // guard let currentTime = player.currentItem?.currentTime().seconds else { return }
        // let total = formatTime(currentAudioDuration!.seconds)
        
        timeLabel.stringValue = "\(current) / \(total)"
    }
        
    private func scrollToFollowPlayback() {
        // guard let player = audioPlayer else { return }
        
        let visibleRect = scrollView.documentVisibleRect
        // let cursorX = 120 + CGFloat(player.currentTime) * waveformView.pixelsPerSecond
        let cursorX = 120 + CGFloat(audioPlaybackManager.currentTime) * waveformView.pixelsPerSecond
        
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
    
    
    @objc private func zoomChanged() {
        waveformView.setZoomLevel(CGFloat(zoomSlider.doubleValue))
        waveformView.updateContentSize()
        
    }
    
    @objc private func waveformViewDidSeek(_ notification: Notification) {
        // guard let player = audioPlayer else { return }  // let time = notification.userInfo?["time"] as? TimeInterval,
        
        // player.currentTime = time
        // player.seek(to: currentTime)
        audioPlaybackManager.seek(to: audioPlaybackManager.currentTime) //CMTime(seconds: time, preferredTimescale: 1)
        waveformView.currentTime = audioPlaybackManager.currentTime
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(waveformViewDidSeek(_:)),
            name: NSNotification.Name("AudioWaveformViewDidSeek"),
            object: waveformView
        )
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time >= 0 else { return "--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }
}


extension AVAssetTrack {
    var channelCount: Int {
        guard let formatDescriptions = formatDescriptions as? [CMAudioFormatDescription],
              let audioFormatDesc = formatDescriptions.first,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDesc)
        else { return 0 }
        
        return Int(asbd.pointee.mChannelsPerFrame)
    }
}
