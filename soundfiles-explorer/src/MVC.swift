//
//  MVC.swift
//  soundfiles-explorer
//
//  Created by Americo Cot on 19/1/26.
//

import Cocoa
import AVKit


private class AudioFile: NSObject {
    @objc let fileName: String
    @objc var scene: String
    @objc var take: String
    @objc var timeCodeStart: String
    let url: URL
    let chCount: Int
    let bitDepth: Int
    let sampleRate: Int
    let bext: BEXTMetadata?
    let ixml: IXMLMetadata?
    
    init(fileName: String,
         scene: String = "",
         take: String = "",
         timeCodeStart: String = "",
         url: URL, chCount: Int,
         bitDepth: Int,
         sampleRate: Int,
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

enum TableColumnIdentifiers: String, CaseIterable {
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
    //MARK: Outlets
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var playerView: AVPlayerView!
    
    //MARK: Variables
    private var player: AVPlayer!
    private var audioFiles: [AudioFile] = []
    private var backupAudioFiles: [AudioFile] = []
    private var notLoadedFiles: [String] = []
    private let metadataReader = AudioMetadataReader()
    
    //MARK: Methods
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupPlayer()
        searchField.delegate = self
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
        
        let timeCodeSortDescriptor = NSSortDescriptor(key: TableColumnIdentifiers.timeCodeStart.rawValue,
                                                   ascending: true,
                                                   selector: #selector(NSString.localizedStandardCompare(_:)))
        if let timeCodeColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: TableColumnIdentifiers.timeCodeStart.rawValue)) {
            timeCodeColumn.sortDescriptorPrototype = timeCodeSortDescriptor
        }
        
    }
    
    private func setupPlayer() {
        self.player = AVPlayer()
        self.playerView.player = self.player
        self.playerView.controlsStyle = .inline
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
        
        //let searchString = searchField.stringValue
        //if searchString.isEmpty {
        //    filteredAudioFiles = audioFiles
        //    } else {
        //        // let placeholder = (searchField.cell as? NSSearchFieldCell)?.placeholderString ?? "All"
        //        var predicate: NSPredicate
        //        predicate = NSPredicate(format: "scene contains %@", searchString)
        //        // switch placeholder {
        //        // case "First Name":
        //        //     predicate = NSPredicate(format: "firstName contains %@", searchString)
        //        // case "Last Name":
        //        //     predicate = NSPredicate(format: "lastName contains %@", searchString)
        //        // default:
        //        //     predicate = NSPredicate(format: "firstName contains %@ OR lastName contains %@", searchString, searchString)
        //        // }

        //        audioFiles = (filteredAudioFiles as NSArray).filtered(using: predicate) as! [AudioFile]
        //    }
        // tableView.reloadData()
    }
    

    private func deleteSelectedRows() {
        let selectedIndexes = tableView.selectedRowIndexes
        // Ensure there is something to delete
        guard !selectedIndexes.isEmpty else { return }
        
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

    
    //MARK: NSTableViewDataSource methods
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
            let tcr = evaluateTimeCodeRate(expressionString: audioFiles[row].ixml!.parsedData["TIMECODE_RATE"]!)
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
                  // audioFiles[row].ixml?.parsedData["CIRCLED"]
            }
            // viewCell.textField!.stringValue = "\(audioFiles[row].ixml?.parsedData["CIRCLED"] ?? "")"
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
    
    // MARK:  TableView Delegate Methods
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        let selectedRow = tableView.selectedRow
        if selectedRow != -1 {
            if self.playerView.player?.rate != 0.0 {
                self.playerView.player?.rate = 0.0
            }
            
            let playerItem = AVPlayerItem(url: audioFiles[selectedRow].url)
            self.player.replaceCurrentItem(with: playerItem)
            
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
        

    // MARK: Keyboard event handlers
    override func keyDown(with event: NSEvent) {
        print(event)
        switch event.keyCode {
        case 51, 117:
            deleteSelectedRows()
        case 49: // Space Bar
            playPause()
            break
        case 38: // J
            playRewind()
            break
        case 40: // K
            playPause()
            break
        case 37: // L
            playForward()
            break
        default:
            super.keyDown(with: event)
        }
    }
    
    
    private func playPause() {
        if playerView.player?.rate == 0.0  {
            playerView.player?.play()
        } else {
            playerView.player?.pause()
        }
    }
    
    private func playRewind() {
        playerView.player?.rate = playerView.player!.rate - 1.5
    }
    
    private func playForward() {
        playerView.player?.rate = playerView.player!.rate + 1.5
    }
    
    
    //MARK: Helpers Functions
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
    
}
