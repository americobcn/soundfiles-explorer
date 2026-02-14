//
//  AC3TableView.swift
//  soundfiles-explorer
//
//  Created by Americo Cot on 13/2/26.
//

import Cocoa

class AC3TableView: NSTableView {
    
    override func keyDown(with event: NSEvent) {
        let zoomOut = 17;
        let zoomIn = 15;
                        
        // handle special keydowns that need to get forwarded (ex: a view controller)
        if (event.keyCode == zoomIn || event.keyCode == zoomOut) {
            return
        } else {
            super.keyDown(with: event)
        }
    }
}
