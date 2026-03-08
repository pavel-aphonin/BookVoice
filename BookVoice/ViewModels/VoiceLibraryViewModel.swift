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
    var newSampleTranscription = ""

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
    func startTraining(
        in context: ModelContext,
        rvcService: any RVCService,
        notificationService: any NotificationService
    ) {
        guard let sampleURL = newSampleAudioURL else { return }

        // Копируем аудио в стабильную директорию (оригинал может быть удалён)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let samplesDir = appSupport.appendingPathComponent("BookVoice/TrainingSamples", isDirectory: true)
        try? FileManager.default.createDirectory(at: samplesDir, withIntermediateDirectories: true)

        let stableSampleURL = samplesDir.appendingPathComponent("\(UUID().uuidString).\(sampleURL.pathExtension)")
        do {
            try FileManager.default.copyItem(at: sampleURL, to: stableSampleURL)
            print("[VoiceTraining] Copied sample to \(stableSampleURL.path)")
        } catch {
            print("[VoiceTraining] ERROR: Failed to copy sample audio: \(error)")
        }

        // Создаём профиль со статусом .pending
        let profileName = newName
        let profileDescription = newDescription
        let transcription = newSampleTranscription

        let profile = VoiceProfile(name: profileName, modelFilePath: "")
        profile.descriptionText = profileDescription
        profile.sampleAudioPath = stableSampleURL.path
        profile.sampleAudioBookmark = try? stableSampleURL.bookmarkData(options: .withSecurityScope)
        profile.sampleTranscription = transcription.isEmpty ? nil : transcription
        profile.trainingStatus = .pending

        context.insert(profile)
        let profileId = profile.id

        resetForm()
        showingCreateSheet = false

        // Запускаем обучение асинхронно
        let modelsDir = appSupport.appendingPathComponent("BookVoice/Models", isDirectory: true)

        Task { [weak self] in
            await self?.runTraining(
                profileId: profileId,
                sampleURL: stableSampleURL,
                modelName: profileName,
                outputDirectory: modelsDir,
                rvcService: rvcService,
                notificationService: notificationService,
                context: context
            )
        }
    }

    @MainActor
    private func runTraining(
        profileId: UUID,
        sampleURL: URL,
        modelName: String,
        outputDirectory: URL,
        rvcService: any RVCService,
        notificationService: any NotificationService,
        context: ModelContext
    ) async {
        // Ищем профиль по ID
        let predicate = #Predicate<VoiceProfile> { $0.id == profileId }
        let descriptor = FetchDescriptor<VoiceProfile>(predicate: predicate)

        guard let profile = try? context.fetch(descriptor).first else {
            print("Training: profile not found for id \(profileId)")
            return
        }

        do {
            // Запускаем обучение на сервере
            print("[VoiceTraining] Starting training for '\(modelName)' with sample: \(sampleURL.path)")
            let jobId = try await rvcService.startTraining(
                sampleAudioURL: sampleURL,
                modelName: modelName,
                outputDirectory: outputDirectory,
                epochs: 100
            )

            print("[VoiceTraining] Training job started: \(jobId)")
            profile.trainingJobId = jobId
            profile.trainingStatus = .training
            try? context.save()

            // Поллим статус каждые 5 секунд
            let maxPollingDuration: TimeInterval = 2 * 60 * 60 // 2 часа
            let startTime = Date()

            while true {
                try await Task.sleep(for: .seconds(5))

                guard Date().timeIntervalSince(startTime) < maxPollingDuration else {
                    print("[VoiceTraining] Training timed out after \(maxPollingDuration)s")
                    profile.trainingStatus = .failed
                    try? context.save()
                    await notificationService.send(
                        title: "Обучение голоса",
                        body: "Обучение «\(modelName)» превысило лимит времени."
                    )
                    return
                }

                let status = try await rvcService.trainingStatus(jobId: jobId)
                profile.trainingProgress = status.progress
                print("[VoiceTraining] Status: \(status.phase.rawValue), progress: \(status.progress)")

                switch status.phase {
                case .completed:
                    if let modelPath = status.modelPath {
                        print("[VoiceTraining] Training completed! Model: \(modelPath)")
                        let modelURL = URL(fileURLWithPath: modelPath)
                        profile.modelFilePath = modelPath
                        profile.modelFileBookmark = try? modelURL.bookmarkData(options: .withSecurityScope)
                    }
                    profile.trainingStatus = .ready
                    profile.trainingJobId = nil
                    try? context.save()
                    await notificationService.send(
                        title: "Голос готов",
                        body: "Голос «\(modelName)» успешно обучен и готов к использованию."
                    )
                    return

                case .failed:
                    print("[VoiceTraining] Training failed: \(status.errorMessage ?? "unknown")")
                    profile.trainingStatus = .failed
                    profile.trainingJobId = nil
                    try? context.save()
                    await notificationService.send(
                        title: "Ошибка обучения",
                        body: "Не удалось обучить голос «\(modelName)»: \(status.errorMessage ?? "неизвестная ошибка")"
                    )
                    return

                case .cancelled:
                    print("[VoiceTraining] Training cancelled")
                    profile.trainingStatus = .failed
                    profile.trainingJobId = nil
                    try? context.save()
                    return

                case .preprocessing, .extractingFeatures, .training:
                    try? context.save()
                    continue
                }
            }

        } catch {
            print("[VoiceTraining] ERROR: Training failed with exception: \(error)")
            profile.trainingStatus = .failed
            profile.trainingJobId = nil
            try? context.save()
            await notificationService.send(
                title: "Ошибка обучения",
                body: "Не удалось обучить голос «\(modelName)»: \(error.localizedDescription)"
            )
        }
    }

    func deleteProfile(_ profile: VoiceProfile, from context: ModelContext) {
        context.delete(profile)
    }

    func resetForm() {
        newName = ""
        newDescription = ""
        newModelURL = nil
        newSampleAudioURL = nil
        newSampleTranscription = ""
    }
}
