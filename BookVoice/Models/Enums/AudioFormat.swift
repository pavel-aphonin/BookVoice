//
//  AudioFormat.swift
//  BookVoice
//

import Foundation
import AVFoundation

enum AudioFormat: String, Codable, CaseIterable {
    case mp3
    case m4a
    case wav
    case flac

    var displayName: String {
        rawValue.uppercased()
    }

    var fileExtension: String {
        rawValue
    }

    var mimeType: String {
        switch self {
        case .mp3: "audio/mpeg"
        case .m4a: "audio/mp4"
        case .wav: "audio/wav"
        case .flac: "audio/flac"
        }
    }

    var avFileType: AVFileType {
        switch self {
        case .mp3: .mp3
        case .m4a: .m4a
        case .wav: .wav
        case .flac: .caf
        }
    }
}
