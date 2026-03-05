//
//  AppConstants.swift
//  BookVoice
//

import Foundation

enum AppConstants: Sendable {
    static let appName = "BookVoice"

    // Default network settings
    static let defaultAPIURL = "http://localhost"
    static let defaultAPIPort = 8080
    static let defaultTimeout: TimeInterval = 30

    // Audio defaults
    static let defaultSampleRate = 22050
    static let defaultSpeed: Double = 1.0
    static let defaultPitch: Double = 1.0

    // RVC defaults
    static let defaultRVCIndexRate: Double = 0.75
    static let defaultRVCFilterRadius = 3
    static let defaultRVCProtectVoiceless: Double = 0.33

    // Segmentation
    static let defaultFixedSegmentLength = 200
    static let maxPreviewSegments = 5

    // UI
    static let animationDuration: Double = 0.3

    // Window
    static let minWindowWidth: CGFloat = 900
    static let minWindowHeight: CGFloat = 600

    // Directories
    nonisolated static var logsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/BookVoice")
    }

    nonisolated static var appSupportDirectory: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls.first!.appendingPathComponent("BookVoice")
    }

    nonisolated static var modelsDirectory: URL {
        appSupportDirectory.appendingPathComponent("Models")
    }

    nonisolated static var llmModelsDirectory: URL {
        appSupportDirectory.appendingPathComponent("Models/LLM")
    }

    nonisolated static var tempAudioDirectory: URL {
        appSupportDirectory.appendingPathComponent("TempAudio")
    }
}
