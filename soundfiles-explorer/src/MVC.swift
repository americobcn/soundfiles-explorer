//
//  MVC.swift
//  soundfiles-explorer
//
//  Created by Americo Cot on 19/1/26.
//

import Cocoa
import AVKit

public struct AudioFile {
    let name: String
    let url: URL
    let bext: BEXTMetadata?
    let ixml: IXMLMetadata?
}


class MVC: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    //MARK: Outlets
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var playerView: AVPlayerView!
    
    var audioFiles: [AudioFile] = []
    var player: AVPlayer!
    let amr = AudioMetadataReader()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerForDraggedTypes([.fileURL])
        tableView.allowsMultipleSelection = false
        self.player = AVPlayer()
        self.playerView.player = self.player
        
        // readFile()
    }
    
    
    //MARK: NSTableViewDataSource methods
    func numberOfRows(in tableView: NSTableView) -> Int {
        audioFiles.count
    }
    
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let colIdentifier = tableColumn?.identifier else { return nil }
        switch colIdentifier {
        case NSUserInterfaceItemIdentifier(rawValue: "fileName"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "fileName"), owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].name)"
            return viewCell
        case NSUserInterfaceItemIdentifier(rawValue: "scene"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "scene"), owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml!.scene ?? "")"
            return viewCell
        case NSUserInterfaceItemIdentifier(rawValue: "take"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "take"), owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml!.take ?? "")"
            return viewCell
        case NSUserInterfaceItemIdentifier(rawValue: "tape"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "tape"), owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml!.parsedData["TAPE"] ?? "")"
            return viewCell
        case NSUserInterfaceItemIdentifier(rawValue: "timeCodeRate"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "timeCodeRate"), owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml!.parsedData["TIMECODE_RATE"] ?? "") \(audioFiles[row].ixml!.parsedData["TIMECODE_FLAG"] ?? "")"
            return viewCell
        case NSUserInterfaceItemIdentifier(rawValue: "channels"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "channels"), owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml!.parsedData["TRACK_COUNT"] ?? "")ch"
            return viewCell
        case NSUserInterfaceItemIdentifier(rawValue: "circled"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "circled"), owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].ixml!.parsedData["CIRCLED"] ?? "")"
            return viewCell
        case NSUserInterfaceItemIdentifier(rawValue: "date"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "date"), owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].bext?.originationDate ?? "")"
            return viewCell
        case NSUserInterfaceItemIdentifier(rawValue: "time"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "time"), owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].bext?.originationTime ?? "")"
            return viewCell
        case NSUserInterfaceItemIdentifier(rawValue: "audioDescription"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "audioDescription"), owner: nil ) as? NSTableCellView
            else { return nil }
            viewCell.textField!.stringValue = "\(audioFiles[row].bext?.codingHistory ?? "")"
            return viewCell
        default:
            return nil
        }
    }

    
    // func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
    //
    // }
    
    
    // MARK:  TableView Delegate Methods
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        let selectedRow = tableView.selectedRow
        if selectedRow != -1 {
            // Pause playing
            if self.playerView.player?.rate != 0.0 {
                self.playerView.player?.rate = 0.0
            }
            let playerItem = AVPlayerItem(url: audioFiles[selectedRow].url)
            self.player.replaceCurrentItem(with: playerItem)
            // Load WAV on the player
            // let selectedFileMetadata = AudioMetadata(bext: audioFiles[selectedRow].bext, ixml: audioFiles[selectedRow].ixml)
            // let rows = amr.extractTableViewRows(from: selectedFileMetadata)
            print("\nFILE DESCRIPTION START")
            //for row in audioFiles[selectedRow].ixml!.parsedData {
            //    print("\(row): \(row.value)")
            //}
            print("BEXT: \(audioFiles[selectedRow].bext)")
            
            print("FILE DESCRIPTION END\n")
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
            
            pasteboardObjects.forEach { (object) in
                if let url = object as? URL {
                    do {
                        let data = try amr.readAudioMetadata(from: url)
                        let audioFile = AudioFile(name: url.lastPathComponent, url: url, bext: data.bext, ixml: data.ixml)
                        self.audioFiles.append(audioFile)
                    } catch {
                        print(error.localizedDescription)
                        let alert = NSAlert()
                        alert.alertStyle = .warning
                        alert.messageText = error.localizedDescription
                        alert.runModal()
                    }
                }
            }
            tableView.reloadData()
            return true
        }
        return false
    }

    
    
    private func readFile() {
        let fileURL = URL(fileURLWithPath: "/Volumes/MediaSSD/So_Directe/2025-11-12.AAN/SL7708_____16_39______1__PN.WAV")
        do {
            let data = try amr.readAudioMetadata(from: fileURL)
            // print("BEXT:\(String(describing: data.bext))\n\niXML:\(String(describing: data.ixml))")
            let rows = amr.extractTableViewRows(from: data)
            for row in rows {
                print("\(row.field): \(row.value)")
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    
}
