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

    var canCreate: Bool {
        !newName.isEmpty && newModelURL != nil
    }

    func importModel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.data]
        panel.message = "Выберите файл модели RVC (.pth)"

        if panel.runModal() == .OK, let url = panel.url {
            newModelURL = url
        }
    }

    func importSampleAudio() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        panel.message = "Выберите аудиофайл с образцом голоса"

        if panel.runModal() == .OK, let url = panel.url {
            newSampleAudioURL = url
        }
    }

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
