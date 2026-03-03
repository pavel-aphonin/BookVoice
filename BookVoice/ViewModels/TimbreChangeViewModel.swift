//
//  TimbreChangeViewModel.swift
//  BookVoice
//

import Foundation
import AppKit
import UniformTypeIdentifiers

@Observable
final class TimbreChangeViewModel {
    var isEnabled: Bool
    var modelPath: String
    var indexRate: Double
    var filterRadius: Int
    var protectVoiceless: Double
    var voiceSampleURL: URL?

    var availableModels: [String] = []
    var isConverting = false
    var progress: Double = 0
    var errorMessage: String?
    var isLoadingModels = false

    // Входные URL от TTS (заполняется WizardViewModel при переходе на шаг 4)
    var audioSegmentURLs: [URL] = []
    // Результаты RVC-конвертации
    var convertedAudioURLs: [URL] = []
    // Выбранный голосовой профиль из библиотеки
    var selectedVoiceProfileId: UUID?

    // Демо-превью
    var isDemoProcessing = false
    var demoAudioURL: URL?
    var demoSegmentIndex: Int = 0

    var isValid: Bool {
        !isEnabled || !modelPath.isEmpty
    }

    private let rvcService: any RVCService
    private let modelManager: any ModelManagerService
    private let audioEngine: any AudioEngineService
    private let notificationService: any NotificationService
    private var conversionTask: Task<Void, Never>?

    init(project: VoiceoverProject, rvcService: any RVCService, modelManager: any ModelManagerService, audioEngine: any AudioEngineService, notificationService: any NotificationService) {
        self.rvcService = rvcService
        self.modelManager = modelManager
        self.audioEngine = audioEngine
        self.notificationService = notificationService
        self.isEnabled = project.rvcEnabled
        self.modelPath = project.rvcModelPath ?? ""
        self.indexRate = project.rvcIndexRate
        self.filterRadius = project.rvcFilterRadius
        self.protectVoiceless = project.rvcProtectVoiceless
    }

    func loadModels() async {
        isLoadingModels = true
        do {
            availableModels = try await rvcService.availableModels(
                at: modelManager.defaultModelDirectory
            )
            if modelPath.isEmpty, let first = availableModels.first {
                modelPath = first
            }
        } catch {
            errorMessage = "Не удалось загрузить модели RVC: \(error.localizedDescription)"
        }
        isLoadingModels = false
    }

    func browseModel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.data]
        panel.message = "Выберите файл модели RVC (.pth)"

        if panel.runModal() == .OK, let url = panel.url {
            modelPath = url.path
        }
    }

    func browseVoiceSample() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        panel.message = "Выберите аудиофайл с образцом голоса"

        if panel.runModal() == .OK, let url = panel.url {
            voiceSampleURL = url
        }
    }

    func convertAll(inputURLs: [URL]) async {
        guard isEnabled, !modelPath.isEmpty else { return }

        isConverting = true
        progress = 0
        errorMessage = nil
        convertedAudioURLs = []

        let outputDir = AppConstants.tempAudioDirectory
            .appendingPathComponent("rvc_\(UUID().uuidString)")

        conversionTask = Task {
            do {
                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

                let results = try await rvcService.convertBatch(
                    inputURLs: inputURLs,
                    outputDirectory: outputDir,
                    modelPath: modelPath,
                    indexRate: indexRate,
                    filterRadius: filterRadius,
                    protectVoiceless: protectVoiceless,
                    progressHandler: { [weak self] prog in
                        guard let self else { return }
                        Task { @MainActor in
                            self.progress = prog
                        }
                    }
                )
                convertedAudioURLs = results
                await notificationService.send(
                    title: "Конвертация тембра готова",
                    body: "\(results.count) сегментов обработано"
                )
            } catch {
                errorMessage = error.localizedDescription
                await notificationService.send(
                    title: "Ошибка конвертации тембра",
                    body: error.localizedDescription
                )
            }
            isConverting = false
        }
    }

    func selectVoiceProfile(_ profile: VoiceProfile) {
        selectedVoiceProfileId = profile.id
        if let url = profile.resolveModelURL() {
            modelPath = url.path
        } else {
            modelPath = profile.modelFilePath
        }
    }

    func previewDemo() async {
        guard !audioSegmentURLs.isEmpty else {
            errorMessage = "Нет аудиосегментов для демо. Сначала выполните озвучку."
            return
        }
        guard !modelPath.isEmpty else {
            errorMessage = "Выберите модель RVC для демо"
            return
        }

        let segmentIndex = min(demoSegmentIndex, audioSegmentURLs.count - 1)
        let inputURL = audioSegmentURLs[segmentIndex]

        isDemoProcessing = true
        errorMessage = nil

        // Удалить предыдущий демо-файл
        if let oldDemo = demoAudioURL {
            try? FileManager.default.removeItem(at: oldDemo)
        }

        do {
            let outputDir = AppConstants.tempAudioDirectory.appendingPathComponent("rvc_demo")
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let outputURL = outputDir.appendingPathComponent("demo_\(UUID().uuidString).wav")

            demoAudioURL = try await rvcService.convert(
                inputURL: inputURL,
                outputURL: outputURL,
                modelPath: modelPath,
                indexRate: indexRate,
                filterRadius: filterRadius,
                protectVoiceless: protectVoiceless
            )

            try await audioEngine.play(url: demoAudioURL!)
        } catch {
            errorMessage = "Ошибка демо: \(error.localizedDescription)"
        }

        isDemoProcessing = false
    }

    func stopDemo() async {
        await audioEngine.stop()
    }

    func cancelConversion() async {
        conversionTask?.cancel()
        await rvcService.cancel()
        isConverting = false
    }

    func saveToProject(_ project: VoiceoverProject) {
        project.rvcEnabled = isEnabled
        project.rvcModelPath = modelPath.isEmpty ? nil : modelPath
        project.rvcIndexRate = indexRate
        project.rvcFilterRadius = filterRadius
        project.rvcProtectVoiceless = protectVoiceless
        project.updatedAt = Date()
    }
}
