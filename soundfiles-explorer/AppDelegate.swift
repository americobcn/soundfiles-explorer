//
//  AppDelegate.swift
//  soundfiles-explorer
//
//  Created by Americo Cot on 19/1/26.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    @IBOutlet weak var mvc: MVC!

    private var projectStore: ProjectStore!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        projectStore = ProjectStore()
        try? projectStore.load()
        mvc.projectStore = projectStore

        let sidebarVC = ProjectSidebarViewController(store: projectStore)
        let splitVC = NSSplitViewController()

        let sidebar = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebar.minimumThickness = 180
        sidebar.maximumThickness = 320

        let contentItem = NSSplitViewItem(viewController: mvc)

        splitVC.addSplitViewItem(sidebar)
        splitVC.addSplitViewItem(contentItem)

        window.contentViewController = splitVC

        if let visibleFrame = window.screen?.visibleFrame {
            var frame = window.frame
            frame.size.width = min(frame.size.width, visibleFrame.width)
            frame.size.height = min(frame.size.height, visibleFrame.height)
            frame.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.size.width)
            frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.size.height)
            window.setFrame(frame, display: false)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        try? projectStore?.save()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

