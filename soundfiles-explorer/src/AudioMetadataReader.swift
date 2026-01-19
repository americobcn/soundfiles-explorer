//
//  AudioMetadataExtractor.swift
//  soundfiles-explorer
//
//  Created by Americo Cot on 19/1/26.
//

import Foundation

// MARK: - BEXT Metadata Structure

public struct BEXTMetadata {
    public let description: String
    public let originator: String
    public let originatorReference: String
    public let originationDate: String
    public let originationTime: String
    public let timeReferenceSamples: UInt64
    public let version: UInt16
    public let umid: String
    public let loudnessValue: Int16
    public let loudnessRange: Int16
    public let maxTruePeakLevel: Int16
    public let maxMomentaryLoudness: Int16
    public let maxShortTermLoudness: Int16
    public let codingHistory: String
    
    // Computed properties for display
    public var timeReferenceFormatted: String {
        return String(timeReferenceSamples)
    }
    
    public var loudnessValueFormatted: String {
        return loudnessValue == Int16.min ? "Not set" : "\(Double(loudnessValue) / 100.0) LUFS"
    }
    
    public var loudnessRangeFormatted: String {
        return loudnessRange == 0 ? "Not set" : "\(Double(loudnessRange) / 100.0) LU"
    }
    
    public var maxTruePeakLevelFormatted: String {
        return maxTruePeakLevel == Int16.min ? "Not set" : "\(Double(maxTruePeakLevel) / 100.0) dBTP"
    }
    
    public var maxMomentaryLoudnessFormatted: String {
        return maxMomentaryLoudness == Int16.min ? "Not set" : "\(Double(maxMomentaryLoudness) / 100.0) LUFS"
    }
    
    public var maxShortTermLoudnessFormatted: String {
        return maxShortTermLoudness == Int16.min ? "Not set" : "\(Double(maxShortTermLoudness) / 100.0) LUFS"
    }
}

// MARK: - iXML Metadata Structure

public struct IXMLMetadata {
    public let rawXML: String
    public let parsedData: [String: String]
    
    // Common iXML fields
    public var project: String? { parsedData["PROJECT"] }
    public var scene: String? { parsedData["SCENE"] }
    public var take: String? { parsedData["TAKE"] }
    public var tape: String? { parsedData["TAPE"] }
    public var circled: String? { parsedData["CIRCLED"] }
    public var wild: String? { parsedData["WILD_TRACK"] }
    public var sampleRate: String? { parsedData["SAMPLE_RATE"] }
    public var audioChannels: String? { parsedData["AUDIO_CHANNELS"] }
    public var fileLength: String? { parsedData["FILE_LENGTH"] }
    public var timecodeRate: String? { parsedData["TIMECODE_RATE"] }
    public var timecodeFlag: String? { parsedData["TIMECODE_FLAG"] }
    public var fileUID: String? { parsedData["FILE_UID"] }
    public var note: String? { parsedData["NOTE"] }
    
    // Track-specific data
    public var tracks: [IXMLTrack] { extractTracks() }
    
    private func extractTracks() -> [IXMLTrack] {
        var tracks: [IXMLTrack] = []
        var trackIndex = 1
        
        while let channelIndex = parsedData["TRACK_\(trackIndex)_CHANNEL_INDEX"] {
            let track = IXMLTrack(
                index: trackIndex,
                channelIndex: channelIndex,
                interleaveIndex: parsedData["TRACK_\(trackIndex)_INTERLEAVE_INDEX"],
                name: parsedData["TRACK_\(trackIndex)_NAME"],
                function: parsedData["TRACK_\(trackIndex)_FUNCTION"]
            )
            tracks.append(track)
            trackIndex += 1
        }
        
        return tracks
    }
}

public struct IXMLTrack {
    public let index: Int
    public let channelIndex: String
    public let interleaveIndex: String?
    public let name: String?
    public let function: String?
}

// MARK: - Combined Audio Metadata

public struct AudioMetadata {
    public let bext: BEXTMetadata?
    public let ixml: IXMLMetadata?
}


// MARK: - Table View Data Source Helper
public struct MetadataRow {
    public let category: String
    public let field: String
    public let value: String
}


final class AudioMetadataReader {
    
    public func extractTableViewRows(from metadata: AudioMetadata) -> [MetadataRow] {
        var rows: [MetadataRow] = []
        
        // BEXT Metadata
        if let bext = metadata.bext {
            rows.append(MetadataRow(category: "BEXT", field: "Description", value: bext.description))
            rows.append(MetadataRow(category: "BEXT", field: "Originator", value: bext.originator))
            rows.append(MetadataRow(category: "BEXT", field: "Originator Reference", value: bext.originatorReference))
            rows.append(MetadataRow(category: "BEXT", field: "Origination Date", value: bext.originationDate))
            rows.append(MetadataRow(category: "BEXT", field: "Origination Time", value: bext.originationTime))
            rows.append(MetadataRow(category: "BEXT", field: "Time Reference", value: bext.timeReferenceFormatted))
            rows.append(MetadataRow(category: "BEXT", field: "Version", value: String(bext.version)))
            rows.append(MetadataRow(category: "BEXT", field: "UMID", value: bext.umid))
            rows.append(MetadataRow(category: "BEXT", field: "Loudness Value", value: bext.loudnessValueFormatted))
            rows.append(MetadataRow(category: "BEXT", field: "Loudness Range", value: bext.loudnessRangeFormatted))
            rows.append(MetadataRow(category: "BEXT", field: "Max True Peak Level", value: bext.maxTruePeakLevelFormatted))
            rows.append(MetadataRow(category: "BEXT", field: "Max Momentary Loudness", value: bext.maxMomentaryLoudnessFormatted))
            rows.append(MetadataRow(category: "BEXT", field: "Max Short Term Loudness", value: bext.maxShortTermLoudnessFormatted))
            
            if !bext.codingHistory.isEmpty {
                rows.append(MetadataRow(category: "BEXT", field: "Coding History", value: bext.codingHistory))
            }
        }
        
        // iXML Metadata
        if let ixml = metadata.ixml {
            if let project = ixml.project {
                rows.append(MetadataRow(category: "iXML", field: "Project", value: project))
            }
            if let scene = ixml.scene {
                rows.append(MetadataRow(category: "iXML", field: "Scene", value: scene))
            }
            if let take = ixml.take {
                rows.append(MetadataRow(category: "iXML", field: "Take", value: take))
            }
            if let tape = ixml.tape {
                rows.append(MetadataRow(category: "iXML", field: "Tape", value: tape))
            }
            if let circled = ixml.circled {
                rows.append(MetadataRow(category: "iXML", field: "Circled", value: circled))
            }
            if let wild = ixml.wild {
                rows.append(MetadataRow(category: "iXML", field: "Wild Track", value: wild))
            }
            if let sampleRate = ixml.sampleRate {
                rows.append(MetadataRow(category: "iXML", field: "Sample Rate", value: sampleRate))
            }
            if let channels = ixml.audioChannels {
                rows.append(MetadataRow(category: "iXML", field: "Audio Channels", value: channels))
            }
            if let fileLength = ixml.fileLength {
                rows.append(MetadataRow(category: "iXML", field: "File Length", value: fileLength))
            }
            if let timecodeRate = ixml.timecodeRate {
                rows.append(MetadataRow(category: "iXML", field: "Timecode Rate", value: timecodeRate))
            }
            if let timecodeFlag = ixml.timecodeFlag {
                rows.append(MetadataRow(category: "iXML", field: "Timecode Flag", value: timecodeFlag))
            }
            if let fileUID = ixml.fileUID {
                rows.append(MetadataRow(category: "iXML", field: "File UID", value: fileUID))
            }
            if let note = ixml.note {
                rows.append(MetadataRow(category: "iXML", field: "Note", value: note))
            }
            
            // Add track information
            for track in ixml.tracks {
                let trackCategory = "iXML Track \(track.index)"
                rows.append(MetadataRow(category: trackCategory, field: "Channel Index", value: track.channelIndex))
                if let interleave = track.interleaveIndex {
                    rows.append(MetadataRow(category: trackCategory, field: "Interleave Index", value: interleave))
                }
                if let name = track.name {
                    rows.append(MetadataRow(category: trackCategory, field: "Name", value: name))
                }
                if let function = track.function {
                    rows.append(MetadataRow(category: trackCategory, field: "Function", value: function))
                }
            }
            
            // Add any additional unparsed fields
            let knownKeys = Set([
                "PROJECT", "SCENE", "TAKE", "TAPE", "CIRCLED", "WILD_TRACK",
                "SAMPLE_RATE", "AUDIO_CHANNELS", "FILE_LENGTH", "TIMECODE_RATE",
                "TIMECODE_FLAG", "FILE_UID", "NOTE"
            ])
            
            for (key, value) in ixml.parsedData.sorted(by: { $0.key < $1.key }) {
                if !knownKeys.contains(key) && !key.hasPrefix("TRACK_") {
                    rows.append(MetadataRow(category: "iXML", field: key, value: value))
                }
            }
        }
        
        return rows
    }

    // MARK: - Main Reading Function
    
    public func readAudioMetadata(from url: URL) throws -> AudioMetadata {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)

        guard data.count > 12 else {
            throw NSError(domain: "AudioParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid file"])
        }

        let riffID = data.readString(at: 0, length: 4)
        guard riffID == "RIFF" else {
            throw NSError(domain: "AudioParser", code: -2, userInfo: [NSLocalizedDescriptionKey: "Not a RIFF file"])
        }

        let waveID = data.readString(at: 8, length: 4)
        guard waveID == "WAVE" else {
            throw NSError(domain: "AudioParser", code: -3, userInfo: [NSLocalizedDescriptionKey: "Not a WAVE file"])
        }

        var offset = 12
        var bext: BEXTMetadata?
        var ixml: IXMLMetadata?

        while offset + 8 <= data.count {
            let chunkID = data.readString(at: offset, length: 4)
            let chunkSize = data.readUInt32LE(at: offset + 4)
            let dataOffset = offset + 8

            if dataOffset + Int(chunkSize) > data.count {
                break
            }

            switch chunkID {
            case "bext":
                bext = parseBEXTChunk(data, offset: dataOffset, size: Int(chunkSize))

            case "iXML":
                ixml = parseIXMLChunk(data, offset: dataOffset, size: Int(chunkSize))

            default:
                break
            }

            // Chunks are word aligned (pad to even)
            let paddedSize = Int(chunkSize + (chunkSize % 2))
            offset = dataOffset + paddedSize
        }

        return AudioMetadata(bext: bext, ixml: ixml)
    }

    // MARK: - BEXT Chunk Parser
    
    private func parseBEXTChunk(_ data: Data, offset: Int, size: Int) -> BEXTMetadata? {
        guard size >= 602 else { return nil } // Minimum size for bext v1

        let description     = data.readCString(at: offset, length: 256)
        let originator      = data.readCString(at: offset + 256, length: 32)
        let originatorRef   = data.readCString(at: offset + 288, length: 32)
        let originationDate = data.readCString(at: offset + 320, length: 10)
        let originationTime = data.readCString(at: offset + 330, length: 8)

        let timeRefLow  = data.readUInt32LE(at: offset + 338)
        let timeRefHigh = data.readUInt32LE(at: offset + 342)
        let timeReferenceSamples = (UInt64(timeRefHigh) << 32) | UInt64(timeRefLow)

        let version = data.readUInt16LE(at: offset + 346)
        
        // UMID (64 bytes starting at offset 348)
        let umid = data.readHexString(at: offset + 348, length: 64)
        
        // Loudness metadata (EBU R 128) - Version 1 and above
        let loudnessValue = data.readInt16LE(at: offset + 412)
        let loudnessRange = data.readInt16LE(at: offset + 414)
        let maxTruePeakLevel = data.readInt16LE(at: offset + 416)
        let maxMomentaryLoudness = data.readInt16LE(at: offset + 418)
        let maxShortTermLoudness = data.readInt16LE(at: offset + 420)
        
        // Reserved area (180 bytes from 422 to 601)
        
        // Coding History starts at offset 602
        let codingHistoryOffset = offset + 602
        let codingHistoryLength = size - 602
        let codingHistory: String
        
        if codingHistoryLength > 0 {
            codingHistory = data.readCString(at: codingHistoryOffset, length: codingHistoryLength)
        } else {
            codingHistory = ""
        }

        return BEXTMetadata(
            description: description,
            originator: originator,
            originatorReference: originatorRef,
            originationDate: originationDate,
            originationTime: originationTime,
            timeReferenceSamples: timeReferenceSamples,
            version: version,
            umid: umid,
            loudnessValue: loudnessValue,
            loudnessRange: loudnessRange,
            maxTruePeakLevel: maxTruePeakLevel,
            maxMomentaryLoudness: maxMomentaryLoudness,
            maxShortTermLoudness: maxShortTermLoudness,
            codingHistory: codingHistory
        )
    }

    // MARK: - iXML Chunk Parser
    
    private func parseIXMLChunk(_ data: Data, offset: Int, size: Int) -> IXMLMetadata? {
        let xmlData = data.subdata(in: offset ..< offset + size)
        guard let xmlString = String(data: xmlData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        
        let parsedData = parseIXMLString(xmlString)
        
        return IXMLMetadata(rawXML: xmlString, parsedData: parsedData)
    }
    
    private func parseIXMLString(_ xml: String) -> [String: String] {
        var result: [String: String] = [:]
        
        // Simple XML parser for iXML data
        let pattern = "<([^/>]+)>([^<]*)</\\1>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }
        
        let nsString = xml as NSString
        let matches = regex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            if match.numberOfRanges == 3 {
                let tagRange = match.range(at: 1)
                let valueRange = match.range(at: 2)
                
                let tag = nsString.substring(with: tagRange).uppercased()
                let value = nsString.substring(with: valueRange).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !value.isEmpty {
                    result[tag] = value
                }
            }
        }
        
        // Parse track information specially
        parseTrackInfo(xml: xml, into: &result)
        
        return result
    }
    
    private func parseTrackInfo(xml: String, into result: inout [String: String]) {
        // Look for TRACK_LIST and individual TRACK elements
        let trackPattern = "<TRACK>.*?</TRACK>"
        guard let trackRegex = try? NSRegularExpression(pattern: trackPattern, options: .dotMatchesLineSeparators) else {
            return
        }
        
        let nsString = xml as NSString
        let trackMatches = trackRegex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for (index, match) in trackMatches.enumerated() {
            let trackXML = nsString.substring(with: match.range)
            let trackNum = index + 1
            
            // Parse individual track fields
            if let channelIndex = extractValue(from: trackXML, tag: "CHANNEL_INDEX") {
                result["TRACK_\(trackNum)_CHANNEL_INDEX"] = channelIndex
            }
            if let interleaveIndex = extractValue(from: trackXML, tag: "INTERLEAVE_INDEX") {
                result["TRACK_\(trackNum)_INTERLEAVE_INDEX"] = interleaveIndex
            }
            if let name = extractValue(from: trackXML, tag: "NAME") {
                result["TRACK_\(trackNum)_NAME"] = name
            }
            if let function = extractValue(from: trackXML, tag: "FUNCTION") {
                result["TRACK_\(trackNum)_FUNCTION"] = function
            }
        }
    }
    
    private func extractValue(from xml: String, tag: String) -> String? {
        let pattern = "<\(tag)>([^<]*)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let nsString = xml as NSString
        guard let match = regex.firstMatch(in: xml, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges == 2 else {
            return nil
        }
        
        let value = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

// MARK: - Data Extension

private extension Data {

    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        let byte0 = UInt16(self[offset])
        let byte1 = UInt16(self[offset + 1])
        return byte0 | (byte1 << 8)
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        let byte0 = UInt32(self[offset])
        let byte1 = UInt32(self[offset + 1])
        let byte2 = UInt32(self[offset + 2])
        let byte3 = UInt32(self[offset + 3])
        return byte0 | (byte1 << 8) | (byte2 << 16) | (byte3 << 24)
    }
    
    func readInt16LE(at offset: Int) -> Int16 {
        guard offset + 2 <= count else { return Int16.min }
        let byte0 = UInt16(self[offset])
        let byte1 = UInt16(self[offset + 1])
        let unsigned = byte0 | (byte1 << 8)
        return Int16(bitPattern: unsigned)
    }

    func readString(at offset: Int, length: Int) -> String {
        guard offset + length <= count else { return "" }
        let sub = subdata(in: offset ..< offset + length)
        return String(decoding: sub, as: UTF8.self)
    }

    func readCString(at offset: Int, length: Int) -> String {
        guard offset + length <= count else { return "" }
        let sub = subdata(in: offset ..< offset + length)
        if let zeroIndex = sub.firstIndex(of: 0) {
            return String(decoding: sub[..<zeroIndex], as: UTF8.self).trimmingCharacters(in: .whitespaces)
        }
        return String(decoding: sub, as: UTF8.self).trimmingCharacters(in: .whitespaces)
    }
    
    func readHexString(at offset: Int, length: Int) -> String {
        guard offset + length <= count else { return "" }
        let sub = subdata(in: offset ..< offset + length)
        return sub.map { String(format: "%02X", $0) }.joined()
    }
}
