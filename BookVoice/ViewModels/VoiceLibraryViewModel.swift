//
//  VoiceLibraryViewModel.swift
//  BookVoice
//

import Foundation
import AppKit
import SwiftData
import UniformTypeIdentifiers

@Observable
final class VoiceLibraryViewModel {
    var showingCreateSheet = false
    var showingDeleteAlert = false
    var profileToDelete: VoiceProfile?

    // Форма создания
    var newName = ""
    var newDescription = ""
    var newModelURL: URL?
    var newSampleAudioURL: URL?

    /// Можно создать из готового файла модели
    var canCreate: Bool {
        !newName.isEmpty && newModelURL != nil
    }

    /// Можно создать из образца голоса (обучение)
    var canCreateFromSample: Bool {
        !newName.isEmpty && newSampleAudioURL != nil
    }

    func importModel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.data]
        panel.message = "Выберите файл модели (.pth)"

        if panel.runModal() == .OK, let url = panel.url {
            newModelURL = url
        }
    }

    func importSampleAudio() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        panel.message = "Выберите аудиозапись с образцом голоса"

        if panel.runModal() == .OK, let url = panel.url {
            newSampleAudioURL = url
        }
    }

    /// Создать профиль из готового файла модели (.pth)
    func createProfile(in context: ModelContext) {
        guard let modelURL = newModelURL else { return }

        let profile = VoiceProfile(name: newName, modelFilePath: modelURL.path)
        profile.descriptionText = newDescription
        profile.modelFileBookmark = try? modelURL.bookmarkData(options: .withSecurityScope)

        if let sampleURL = newSampleAudioURL {
            profile.sampleAudioPath = sampleURL.path
            profile.sampleAudioBookmark = try? sampleURL.bookmarkData(options: .withSecurityScope)
        }

        context.insert(profile)
        resetForm()
        showingCreateSheet = false
    }

    /// Начать обучение из образца голоса.
    /// Создаёт профиль со статусом «обучается» — обучение RVC запускается асинхронно.
    func startTraining(in context: ModelContext) {
        guard let sampleURL = newSampleAudioURL else { return }

        // Создаём профиль с временным путём (будет заменён после обучения)
        let profile = VoiceProfile(name: newName, modelFilePath: "")
        profile.descriptionText = newDescription
        profile.sampleAudioPath = sampleURL.path
        profile.sampleAudioBookmark = try? sampleURL.bookmarkData(options: .withSecurityScope)
        profile.trainingStatus = .pending

        context.insert(profile)
        resetForm()
        showingCreateSheet = false

        // TODO: запустить обучение RVC асинхронно через RVCService
        // После обучения — обновить profile.modelFilePath и profile.trainingStatus = .ready
    }

    func deleteProfile(_ profile: VoiceProfile, from context: ModelContext) {
        context.delete(profile)
    }

    func resetForm() {
        newName = ""
        newDescription = ""
        newModelURL = nil
        newSampleAudioURL = nil
    }
}
