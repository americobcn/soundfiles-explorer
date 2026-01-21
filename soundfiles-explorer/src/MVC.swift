//
//  MVC.swift
//  soundfiles-explorer
//
//  Created by Americo Cot on 19/1/26.
//

import Cocoa
import AVKit


private struct AudioFile {
    let name: String
    let url: URL
    let chCount: Int
    let bitDepth: Int
    let sampleRate: Float
    let bext: BEXTMetadata?
    let ixml: IXMLMetadata?
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


class MVC: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    //MARK: Outlets
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var playerView: AVPlayerView!
    
    //MARK: Variables
    private var player: AVPlayer!
    private var audioFiles: [AudioFile] = []
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
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerForDraggedTypes([.fileURL])
        tableView.allowsMultipleSelection = false
        let descriptor = NSSortDescriptor(key: "scene", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
        tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("scene"))?.sortDescriptorPrototype = descriptor
    }
    
    private func setupPlayer() {
        self.player = AVPlayer()
        self.playerView.player = self.player
        self.playerView.controlsStyle = .inline
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
            viewCell.textField!.stringValue = "\(audioFiles[row].name)"
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
            var TCStart: String = ""
            if let bext = audioFiles[row].bext, let ixml = audioFiles[row].ixml {
                if let sr = ixml.parsedData["TIMESTAMP_SAMPLE_RATE"],  let tcr = ixml.parsedData["TIMECODE_RATE"] { //let tcr = ixml.parsedData["DISPLAYED_TC_FPS"]
                    let splitedTCR = tcr.split(separator: "/")
                    TCStart = timecodeFromTimeReference(samples: Int64(bext.timeReferenceSamples),
                                                        sampleRate: Double(sr)!,
                                                        frameRate: Double(splitedTCR[0])!
                    )
                }
            }
            
            viewCell.textField!.stringValue = TCStart
            return viewCell
        case .timeCodeRate:
            guard let viewCell = tableView.makeView(withIdentifier: colIdentifier, owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml?.parsedData["DISPLAYED_TC_FPS"] ?? "") \(audioFiles[row].ixml?.parsedData["TIMECODE_FLAG"] ?? "")"
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
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml?.parsedData["CIRCLED"] ?? "")"
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
            print("\nFILE DESCRIPTION START")
            print("BEXT: \(audioFiles[selectedRow].bext)\n")
            print("iXML(parsedData): \(audioFiles[selectedRow].ixml?.parsedData)")
            print("iXML(rawData): \(audioFiles[selectedRow].ixml?.rawXML ?? "")")
            print("FILE DESCRIPTION END\n")
            #endif
        }
    }
    
    
    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation
    {
        if info.draggingPasteboard.types?.contains(.fileURL) == true {
            // File Drop (from Finder)
            tableView.setDropRow(row, dropOperation: .above)
            return .copy
        }
        return []
    }
    
    
        
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool
    {
        if info.draggingPasteboard.types?.contains(.fileURL) == true {
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
                            let audioFile = AudioFile(name: url.deletingPathExtension().lastPathComponent,
                                                      url: url,
                                                      chCount: Int(asbd.mChannelsPerFrame),
                                                      bitDepth: Int(asbd.mBitsPerChannel),
                                                      sampleRate: Float(asbd.mSampleRate),
                                                      bext: data.bext,
                                                      ixml: data.ixml)
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
        let mutableArray = NSMutableArray(array: audioFiles)
        mutableArray.sort(using: tableView.sortDescriptors)
        audioFiles = mutableArray as! [AudioFile]
        tableView.reloadData()
    }

    
    
    // MARK: Keyboard event handlers
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
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
                
}

