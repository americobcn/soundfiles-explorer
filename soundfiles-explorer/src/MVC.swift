//
//  MVC.swift
//  soundfiles-explorer
//
//  Created by Americo Cot on 19/1/26.
//

import Cocoa

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
    
    var audioFiles: [AudioFile] = []
    let audioMetadataReader = AudioMetadataReader()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        readFile()
    }
    
    
    //MARK: NSTableViewDataSource methods
    func numberOfRows(in tableView: NSTableView) -> Int {
        audioFiles.count
    }
    
    // func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
    //
    // }
    
    //MARK: NSTableViewDelegate methods
    
    

    private func readFile() {
        let fileURL = URL(fileURLWithPath: "/Volumes/MediaSSD/So_Directe/2025-11-12.AAN/SL7708_____16_39______1__PN.WAV")
        do {
            let data = try audioMetadataReader.readAudioMetadata(from: fileURL)
            // print("BEXT:\(String(describing: data.bext))\n\niXML:\(String(describing: data.ixml))")
            let rows = audioMetadataReader.extractTableViewRows(from: data)
            for row in rows {
                print("\(row.field): \(row.value)")
            }
            
            
        } catch {
            print(error.localizedDescription)
        }
    }
}

