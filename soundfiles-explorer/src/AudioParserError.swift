//
//  AudioParserError.swift
//  soundfiles-explorer
//
//  Created by Americo Cot on 21/1/26.
//

import Foundation

enum AudioParserError: Error, LocalizedError {
      case invalidFile
      case notRiff
      case notWave
      case noAudioTrack
      case malformedMetadata

      var errorDescription: String? {
          switch self {
          case .invalidFile: return "File is too small or corrupted."
          case .notRiff: return "File does not start with RIFF."
          case .notWave: return "RIFF file is not a WAVE format."
          case .noAudioTrack: return "No audio track found in the asset."
          case .malformedMetadata: return "Unable to parse metadata."
          }
      }
  }
