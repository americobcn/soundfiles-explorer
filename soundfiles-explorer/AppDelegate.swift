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
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        try? projectStore?.save()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

