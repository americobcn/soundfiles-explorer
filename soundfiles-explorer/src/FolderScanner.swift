import Foundation

struct ScanResult {
    let audioFileURLs: [URL]
    let soundReportURLs: [URL]
    let scannedFolderURLs: [URL]
}

final class FolderScanner {
    static let audioExtensions: Set<String> = ["wav", "aiff", "aif", "mp3", "flac", "caf"]
    static let reportExtensions: Set<String> = ["csv", "xlsx", "pdf", "xml", "json", "html"]

    func scan(folders: [URL]) async -> ScanResult {
        await Task.detached(priority: .utility) {
            var audioURLs: [URL] = []
            var reportURLs: [URL] = []
            let keys: [URLResourceKey] = [.isRegularFileKey]
            let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]

            for folder in folders {
                guard let enumerator = FileManager.default.enumerator(
                    at: folder,
                    includingPropertiesForKeys: keys,
                    options: options
                ) else { continue }

                while let obj = enumerator.nextObject(), let url = obj as? URL {
                    guard (try? url.resourceValues(forKeys: Set(keys)).isRegularFile) == true else { continue }
                    let ext = url.pathExtension.lowercased()
                    
#if compiler(<6.1)
                    if Self.audioExtensions.contains(ext) {
                        audioURLs.append(url)
                    } else if Self.reportExtensions.contains(ext) {
                        reportURLs.append(url)
                    }
#else
                    if await Self.audioExtensions.contains(ext) {
                        audioURLs.append(url)
                    } else if await Self.reportExtensions.contains(ext) {
                        reportURLs.append(url)
                    }
#endif
                }
            }

            return ScanResult(
                audioFileURLs: audioURLs,
                soundReportURLs: reportURLs,
                scannedFolderURLs: folders
            )
        }.value
    }
}
