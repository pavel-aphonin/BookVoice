//
//  URL+BookVoice.swift
//  BookVoice
//

import Foundation

extension URL {
    static func ensureDirectoryExists(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    static var bookVoiceAppSupport: URL {
        AppConstants.appSupportDirectory
    }

    static var bookVoiceLogs: URL {
        AppConstants.logsDirectory
    }

    static var bookVoiceModels: URL {
        AppConstants.modelsDirectory
    }

    static var bookVoiceTempAudio: URL {
        AppConstants.tempAudioDirectory
    }
}
