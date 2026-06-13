import Cocoa

final class ProjectSidebarViewController: NSViewController {

    private let store: ProjectStore
    private var projectTableView: NSTableView!
    private var reportTableView: NSTableView!
    private var reportSection: NSView!

    init(store: ProjectStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("use init(store:)") }

    // MARK: - View Lifecycle

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAddButton()
        setupProjectTable()
        setupReportSection()
        setupNotifications()
    }

    // MARK: - Setup

    private func setupAddButton() {
        let button = NSButton(title: "+ New Project", target: self, action: #selector(openFolderPicker))
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
        ])
    }

    private func setupProjectTable() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let table = NSTableView()
        table.headerView = nil
        table.rowHeight = 22
        table.allowsMultipleSelection = false
        table.delegate = self
        table.dataSource = self
        table.registerForDraggedTypes([.fileURL])
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("project"))
        col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        scrollView.documentView = table
        projectTableView = table

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Add Folder to Project...", action: #selector(addFolderToProject), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Rename", action: #selector(renameProject), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Delete Project", action: #selector(deleteProject), keyEquivalent: ""))
        table.menu = menu

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.55),
        ])
    }

    private func setupReportSection() {
        reportSection = NSView()
        reportSection.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        reportSection.addSubview(divider)

        let titleLabel = NSTextField(labelWithString: "Sound Reports")
        titleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        reportSection.addSubview(titleLabel)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let table = NSTableView()
        table.headerView = nil
        table.rowHeight = 20
        table.delegate = self
        table.dataSource = self
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("report"))
        col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        scrollView.documentView = table
        reportTableView = table
        reportSection.addSubview(scrollView)

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: reportSection.topAnchor),
            divider.leadingAnchor.constraint(equalTo: reportSection.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: reportSection.trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: reportSection.leadingAnchor, constant: 8),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: reportSection.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: reportSection.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: reportSection.bottomAnchor),
        ])

        view.addSubview(reportSection)
        NSLayoutConstraint.activate([
            reportSection.topAnchor.constraint(equalTo: projectTableView.enclosingScrollView!.bottomAnchor),
            reportSection.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            reportSection.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            reportSection.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(projectStoreChanged),
            name: ProjectStore.projectDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(projectStoreChanged),
            name: ProjectStore.projectListDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Actions

    @objc private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Create Project"
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            self?.scanAndCreateOrAppend(folders: panel.urls, intent: .createNew)
        }
    }

    @objc private func addFolderToProject() {
        let row = projectTableView.clickedRow
        guard row >= 0, row < store.projects.count else { return }
        let project = store.projects[row]
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add Folder"
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            self?.scanAndCreateOrAppend(folders: panel.urls, intent: .appendTo(project.id))
        }
    }

    @objc private func renameProject() {
        let row = projectTableView.clickedRow
        guard row >= 0, row < store.projects.count else { return }
        guard let cellView = projectTableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
              let textField = cellView.textField else { return }
        view.window?.makeFirstResponder(textField)
    }

    @objc private func deleteProject() {
        let row = projectTableView.clickedRow
        guard row >= 0, row < store.projects.count else { return }
        let project = store.projects[row]
        let alert = NSAlert()
        alert.messageText = "Delete \"\(project.name)\"?"
        alert.informativeText = "The project will be removed from the list. Your files will not be deleted."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            try? self?.store.delete(id: project.id)
            self?.projectTableView.reloadData()
            self?.reportTableView.reloadData()
            self?.projectTableView.deselectAll(nil)
        }
    }

    @objc private func projectStoreChanged() {
        projectTableView.reloadData()
        reportTableView.reloadData()
        if let active = store.activeProject,
           let idx = store.projects.firstIndex(where: { $0.id == active.id }) {
            projectTableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }
    }

    // MARK: - Scan and Create/Append

    private func scanAndCreateOrAppend(folders: [URL], intent: FolderScanIntent) {
        Task { @MainActor in
            let scanner = FolderScanner()
            let result = await scanner.scan(folders: folders)
            // Notify MVC via a temporary notification carrying the scan result
            NotificationCenter.default.post(
                name: .sidebarRequestsFolderScan,
                object: nil,
                userInfo: ["folders": folders, "scanResult": result, "intent": intent]
            )
        }
    }
}

// MARK: - Folder Scan Intent

enum FolderScanIntent {
    case createNew
    case appendTo(UUID)
}

// MARK: - NSNotification extension

extension Notification.Name {
    static let sidebarRequestsFolderScan = Notification.Name("SidebarRequestsFolderScan")
}

// MARK: - NSTableViewDataSource

extension ProjectSidebarViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === projectTableView { return store.projects.count }
        if tableView === reportTableView { return store.activeProject?.soundReportRecords.count ?? 0 }
        return 0
    }

    private func draggedFolderURLs(from info: NSDraggingInfo) -> [URL] {
        guard let objects = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) else { return [] }
        return objects.compactMap { $0 as? URL }.filter(\.hasDirectoryPath)
    }

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation
    {
        guard !draggedFolderURLs(from: info).isEmpty else { return [] }

        if dropOperation == .on, row >= 0, row < store.projects.count {
            tableView.setDropRow(row, dropOperation: .on)
        } else {
            tableView.setDropRow(store.projects.count, dropOperation: .above)
        }
        return .copy
    }

    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool
    {
        let folders = draggedFolderURLs(from: info)
        guard !folders.isEmpty else { return false }

        if dropOperation == .on, row >= 0, row < store.projects.count {
            scanAndCreateOrAppend(folders: folders, intent: .appendTo(store.projects[row].id))
        } else {
            scanAndCreateOrAppend(folders: folders, intent: .createNew)
        }
        return true
    }
}

// MARK: - NSTableViewDelegate

extension ProjectSidebarViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === projectTableView {
            let id = NSUserInterfaceItemIdentifier("projectCell")
            let cell = (tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView) ?? {
                let c = NSTableCellView()
                c.identifier = id
                let tf = NSTextField()
                tf.isBordered = false
                tf.isEditable = true
                tf.drawsBackground = false
                tf.translatesAutoresizingMaskIntoConstraints = false
                tf.delegate = self
                c.textField = tf
                c.addSubview(tf)
                NSLayoutConstraint.activate([
                    tf.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4),
                    tf.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -4),
                    tf.centerYAnchor.constraint(equalTo: c.centerYAnchor),
                ])
                return c
            }()
            cell.textField?.stringValue = store.projects[row].name
            cell.textField?.isEditable = false
            return cell
        }

        if tableView === reportTableView {
            let id = NSUserInterfaceItemIdentifier("reportCell")
            let cell = (tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView) ?? {
                let c = NSTableCellView()
                c.identifier = id
                let tf = NSTextField()
                tf.isBordered = false
                tf.isEditable = false
                tf.drawsBackground = false
                tf.translatesAutoresizingMaskIntoConstraints = false
                c.textField = tf
                c.addSubview(tf)
                NSLayoutConstraint.activate([
                    tf.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4),
                    tf.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -4),
                    tf.centerYAnchor.constraint(equalTo: c.centerYAnchor),
                ])
                return c
            }()
            if let report = store.activeProject?.soundReportRecords[row] {
                cell.textField?.stringValue = "\(report.fileName).\(report.fileExtension)"
            }
            return cell
        }

        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView,
              tableView === projectTableView else { return }
        let row = tableView.selectedRow
        guard row >= 0, row < store.projects.count else { return }
        store.activate(store.projects[row])
        reportTableView.reloadData()
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return tableView === projectTableView
    }
}

// MARK: - NSTextFieldDelegate (inline rename)

extension ProjectSidebarViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let tf = obj.object as? NSTextField else { return }
        let row = projectTableView.row(for: tf.superview ?? tf)
        guard row >= 0, row < store.projects.count else { return }
        let newName = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else {
            tf.stringValue = store.projects[row].name
            return
        }
        try? store.rename(id: store.projects[row].id, name: newName)
        tf.isEditable = false
    }
}
