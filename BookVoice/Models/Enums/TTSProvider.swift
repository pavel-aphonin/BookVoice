//
//  TTSProvider.swift
//  BookVoice
//

import Foundation

enum TTSProvider: String, Codable, CaseIterable {
    case silero
    case elevenLabs
    case kokoro
    case custom

    var displayName: String {
        switch self {
        case .silero: "Silero TTS"
        case .elevenLabs: "ElevenLabs"
        case .kokoro: "Kokoro TTS"
        case .custom: "Custom API"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .elevenLabs: true
        default: false
        }
    }

    var isLocal: Bool {
        switch self {
        case .silero, .kokoro: true
        case .elevenLabs, .custom: false
        }
    }
}
