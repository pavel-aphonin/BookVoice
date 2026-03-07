//
//  VoiceProfile.swift
//  BookVoice
//

import SwiftData
import Foundation

enum VoiceTrainingStatus: Int, Codable {
    case ready = 0       // Модель готова к использованию
    case pending = 1     // Ожидает обучения
    case training = 2    // Обучается
    case failed = 3      // Ошибка обучения
}

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
    var trainingStatusRaw: Int
    var trainingJobId: String?
    var trainingProgress: Double?
    var sampleTranscription: String?

    var trainingStatus: VoiceTrainingStatus {
        get { VoiceTrainingStatus(rawValue: trainingStatusRaw) ?? .ready }
        set { trainingStatusRaw = newValue.rawValue }
    }

    /// Модель готова к использованию
    var isReady: Bool { trainingStatus == .ready && !modelFilePath.isEmpty }

    init(name: String, modelFilePath: String) {
        self.id = UUID()
        self.name = name
        self.descriptionText = ""
        self.modelFilePath = modelFilePath
        self.createdAt = Date()
        self.tags = []
        self.trainingStatusRaw = modelFilePath.isEmpty
            ? VoiceTrainingStatus.pending.rawValue
            : VoiceTrainingStatus.ready.rawValue
        self.trainingProgress = 0
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

    /// Разрешает security-scoped доступ к аудиообразцу
    func resolveSampleAudioURL() -> URL? {
        if let bookmark = sampleAudioBookmark {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) {
                if isStale {
                    sampleAudioBookmark = try? url.bookmarkData(options: .withSecurityScope)
                }
                return url
            }
        }
        if let path = sampleAudioPath, !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        return nil
    }
}
