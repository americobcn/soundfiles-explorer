import Foundation

/// Machine-wide storage under /Users/Shared so every user account sees the same projects and caches.
nonisolated enum SharedStorage {
    static let root = URL(fileURLWithPath: "/Users/Shared/soundfiles-explorer", isDirectory: true)
    static let projectsFile = root.appendingPathComponent("projects.json")
    static let waveformsDirectory = root.appendingPathComponent("waveforms", isDirectory: true)

    /// Creates `url` (and `root` if missing) and opens newly created directories to all users.
    /// The umask strips group/other write bits at creation time, hence the explicit `setAttributes`.
    static func ensureDirectory(_ url: URL) throws {
        let fm = FileManager.default
        for dir in [root, url] where !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: false)
            try fm.setAttributes([.posixPermissions: 0o777], ofItemAtPath: dir.path)
        }
    }
}
