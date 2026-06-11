import Foundation

@MainActor
final class ProjectStore {
    static let projectDidChangeNotification = Notification.Name("ProjectDidChange")
    static let projectListDidChangeNotification = Notification.Name("ProjectListDidChange")
    static let projectDidDeleteNotification = Notification.Name("ProjectDidDelete")

    private(set) var projects: [Project] = []
    private(set) var activeProject: Project?

    private var saveTask: Task<Void, Never>?

    // MARK: - Load / Save

    func load() throws {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        let data = try Data(contentsOf: storeURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        projects = try decoder.decode([Project].self, from: data)
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(projects)
        let dir = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: storeURL, options: .atomic)
    }

    /// Coalesces rapid mutations into a single disk write ~0.4s after the last change.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            try? self.save()
        }
    }

    private var storeURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appendingPathComponent("com.americobcn.soundfiles-explorer")
            .appendingPathComponent("projects.json")
    }

    // MARK: - Mutations

    @discardableResult
    func createProject(name: String, scanResult: ScanResult, audioFileInfos: [AudioFileInfo]) throws -> Project {
        let records = audioFileInfos.map { AudioFileRecord(from: $0) }
        let reports = scanResult.soundReportURLs.map { url -> SoundReportRecord in
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return SoundReportRecord(
                url: url,
                fileName: url.deletingPathExtension().lastPathComponent,
                fileExtension: url.pathExtension.lowercased(),
                modifiedDate: attrs?[.modificationDate] as? Date
            )
        }
        let now = Date()
        let project = Project(
            id: UUID(),
            name: name,
            createdAt: now,
            lastOpenedAt: now,
            sourceFolderURLs: scanResult.scannedFolderURLs,
            audioFileRecords: records,
            soundReportRecords: reports
        )
        projects.append(project)
        try save()
        activeProject = project
        NotificationCenter.default.post(name: Self.projectListDidChangeNotification, object: project)
        return project
    }

    func appendFolders(_ urls: [URL], to id: UUID, scanResult: ScanResult, newInfos: [AudioFileInfo]) throws {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        let newRecords = newInfos.map { AudioFileRecord(from: $0) }
        let newReports = scanResult.soundReportURLs.map { url -> SoundReportRecord in
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return SoundReportRecord(
                url: url,
                fileName: url.deletingPathExtension().lastPathComponent,
                fileExtension: url.pathExtension.lowercased(),
                modifiedDate: attrs?[.modificationDate] as? Date
            )
        }
        projects[idx].sourceFolderURLs.append(contentsOf: urls)
        projects[idx].audioFileRecords.append(contentsOf: newRecords)
        projects[idx].soundReportRecords.append(contentsOf: newReports)
        projects[idx].lastOpenedAt = Date()
        activeProject = projects[idx]
        try save()
        NotificationCenter.default.post(name: Self.projectListDidChangeNotification, object: activeProject)
    }

    func updateAudioFileRecord(url: URL, with info: AudioFileInfo) throws {
        guard let pid = info.projectID,
              let idx = projects.firstIndex(where: { $0.id == pid }),
              let ridx = projects[idx].audioFileRecords.firstIndex(where: { $0.url == url }) else { return }
        projects[idx].audioFileRecords[ridx] = AudioFileRecord(from: info)
        scheduleSave()
    }

    func activate(_ project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        // Re-entrancy guard: activate() -> projectDidChangeNotification -> sidebar
        // re-selects the row -> tableViewSelectionDidChange -> activate() again.
        // Without this, re-selecting the already-active project loops forever.
        guard activeProject?.id != project.id else { return }
        projects[idx].lastOpenedAt = Date()
        activeProject = projects[idx]
        try? save()
        NotificationCenter.default.post(name: Self.projectDidChangeNotification, object: activeProject)
    }

    func delete(id: UUID) throws {
        projects.removeAll { $0.id == id }
        if activeProject?.id == id { activeProject = nil }
        try save()
        NotificationCenter.default.post(name: Self.projectDidDeleteNotification, object: id)
    }

    func rename(id: UUID, name: String) throws {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].name = name
        if activeProject?.id == id { activeProject = projects[idx] }
        try save()
    }
}

// MARK: - AudioFileRecord convenience init

private extension AudioFileRecord {
    init(from info: AudioFileInfo) {
        let stringKeys = Dictionary(uniqueKeysWithValues: info.tracksNames.map { (String($0.key), $0.value) })
        self.init(
            url: info.url,
            fileName: info.fileName,
            duration: info.duration,
            sampleRate: info.sampleRate,
            channelCount: info.channelCount,
            bitDepth: info.bitDepth,
            formatID: info.formatID,
            scene: info.scene,
            take: info.take,
            date: info.date,
            timeCodeStart: info.timeCodeStart,
            tracksNames: stringKeys
        )
    }
}
