//
//  VoiceProfile.swift
//  BookVoice
//

import SwiftData
import Foundation

@Model
final class VoiceProfile {
    var id: UUID
    var name: String
    var descriptionText: String
    var modelFilePath: String
    var modelFileBookmark: Data?
    var sampleAudioPath: String?
    var sampleAudioBookmark: Data?
    var createdAt: Date
    var tags: [String]

    init(name: String, modelFilePath: String) {
        self.id = UUID()
        self.name = name
        self.descriptionText = ""
        self.modelFilePath = modelFilePath
        self.createdAt = Date()
        self.tags = []
    }

    /// Разрешает security-scoped доступ к файлу модели
    func resolveModelURL() -> URL? {
        if let bookmark = modelFileBookmark {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) {
                if isStale {
                    modelFileBookmark = try? url.bookmarkData(options: .withSecurityScope)
                }
                return url
            }
        }
        let url = URL(fileURLWithPath: modelFilePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
