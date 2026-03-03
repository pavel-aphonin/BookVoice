//
//  TTSProvider.swift
//  BookVoice
//

import Foundation

enum TTSProvider: String, Codable, CaseIterable {
    case silero
    case elevenLabs
    case kokoro
    case qwenLocal
    case qwenCloud
    case custom

    var displayName: String {
        switch self {
        case .silero: "Silero TTS"
        case .elevenLabs: "ElevenLabs"
        case .kokoro: "Kokoro TTS"
        case .qwenLocal: "Qwen3 TTS (локально)"
        case .qwenCloud: "Qwen3 TTS (DashScope)"
        case .custom: "Свой API"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .elevenLabs, .qwenCloud: true
        default: false
        }
    }

    var isLocal: Bool {
        switch self {
        case .silero, .kokoro, .qwenLocal: true
        case .elevenLabs, .qwenCloud, .custom: false
        }
    }
}
