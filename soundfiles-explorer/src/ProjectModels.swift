import Foundation

struct Project: Codable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var lastOpenedAt: Date
    var sourceFolderURLs: [URL]
    var audioFileRecords: [AudioFileRecord]
    var soundReportRecords: [SoundReportRecord]
}

struct AudioFileRecord: Codable {
    var url: URL
    var fileName: String
    var duration: TimeInterval
    var sampleRate: Double
    var channelCount: Int
    var bitDepth: Int
    var formatID: String
    var scene: String
    var take: String
    var date: String
    var timeCodeStart: String
    var tracksNames: [String: String]
}

struct SoundReportRecord: Codable {
    var url: URL
    var fileName: String
    var fileExtension: String
    var modifiedDate: Date?
}
