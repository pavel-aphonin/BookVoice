//
//  VoiceoverViewModel.swift
//  BookVoice
//

import AppKit
import Foundation
import UniformTypeIdentifiers

struct SegmentSynthesisState: Identifiable {
    let id: Int
    let index: Int
    let fullText: String
    let previewText: String
    var status: Status = .pending
    var audioURL: URL?

    enum Status {
        case pending, inProgress, completed, failed
    }

    var statusIcon: String {
        switch status {
        case .pending: "circle"
        case .inProgress: "arrow.clockwise.circle"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    var statusColor: SwiftUI.Color {
        switch status {
        case .pending: .secondary
        case .inProgress: .orange
        case .completed: .green
        case .failed: .red
        }
    }

    var isCompleted: Bool { status == .completed }
}

import SwiftUI

@Observable
final class VoiceoverViewModel {
    var selectedModel: String = ""
    var availableModels: [String] = []
    var speed: Double
    var pitch: Double
    var emotion: String = ""

    // --- Расширенные параметры генерации (Qwen) ---
    var selectedSpeaker: String = ""
    var selectedLanguage: String = ""
    var temperature: Double = -1       // -1 = авто (0.9)
    var topK: Int = -1                 // -1 = авто (50)
    var topP: Double = -1              // -1 = авто (1.0)
    var repetitionPenalty: Double = -1  // -1 = авто (1.05)
    var doSample: Bool = true
    var maxNewTokens: Int = -1             // -1 = авто (2048)
    // --- Voice cloning (Qwen Base models) ---
    var referenceAudioURL: URL?
    var referenceText: String = ""
    var xVectorOnlyMode: Bool = false
    // --- Subtalker (клонирование голоса) ---
    var subtalkerTemperature: Double = -1
    var subtalkerTopK: Int = -1
    var subtalkerTopP: Double = -1
    var subtalkerDoSample: Bool = true

    var isSynthesizing = false
    var progress: Double = 0
    var currentSegmentIndex: Int = 0
    var totalSegments: Int = 0
    var segmentStates: [SegmentSynthesisState] = []
    var errorMessage: String?
    var isLoadingModels = false

    var isReady: Bool {
        segmentStates.allSatisfy { $0.isCompleted }
    }

    /// Тип Qwen-модели по имени: base, custom_voice, voice_design
    var qwenModelType: String {
        let lower = selectedModel.lowercased()
        if lower.contains("customvoice") || lower.contains("custom-voice") {
            return "custom_voice"
        } else if lower.contains("voicedesign") || lower.contains("voice-design") {
            return "voice_design"
        } else if lower.contains("base") {
            return "base"
        }
        return "custom_voice"
    }

    /// Показывать поле инструкции/эмоции (CustomVoice + Cloud)
    var supportsEmotion: Bool {
        if provider == .qwenCloud { return true }
        if provider == .qwenLocal { return qwenModelType == "custom_voice" }
        return false
    }

    /// Показывать расширенные настройки генерации (все локальные Qwen-модели)
    var supportsAdvancedOptions: Bool {
        provider == .qwenLocal
    }

    /// Показывать выбор спикера (Silero + CustomVoice Qwen)
    var supportsSpeakerSelection: Bool {
        if provider == .silero { return true }
        if provider == .qwenLocal { return qwenModelType == "custom_voice" }
        return false
    }

    /// Показывать выбор языка (все локальные Qwen-модели)
    var supportsLanguageSelection: Bool {
        provider == .qwenLocal
    }

    /// Показывать загрузку reference-аудио (Base-модели — клонирование голоса)
    var supportsReferenceVoice: Bool {
        provider == .qwenLocal && qwenModelType == "base"
    }

    /// Показывать описание голоса (VoiceDesign)
    var supportsVoiceDescription: Bool {
        provider == .qwenLocal && qwenModelType == "voice_design"
    }

    /// Доступные спикеры для текущего провайдера и модели
    var availableSpeakers: [String] {
        switch provider {
        case .qwenLocal:
            guard qwenModelType == "custom_voice" else { return [] }
            return ["aiden", "dylan", "eric", "ono_anna", "ryan", "serena", "sohee", "uncle_fu", "vivian"]
        case .silero:
            // Зависит от модели — v4_ru, v3_en и т.д.
            if selectedModel.contains("ru") {
                return ["aidar", "baya", "kseniya", "xenia", "eugene", "random"]
            } else if selectedModel.contains("en") {
                return (0..<10).map { "en_\($0)" } + ["random"]
            } else {
                return ["random"]
            }
        default:
            return []
        }
    }

    /// Доступные языки
    var availableLanguages: [String] {
        ["auto", "russian", "english", "chinese", "french", "german", "italian", "japanese", "korean", "portuguese", "spanish"]
    }

    /// Построить TTSGenerationOptions из текущих настроек
    private var generationOptions: TTSGenerationOptions {
        var opts = TTSGenerationOptions(
            speaker: selectedSpeaker,
            language: selectedLanguage,
            temperature: temperature,
            topK: topK,
            topP: topP,
            repetitionPenalty: repetitionPenalty,
            doSample: doSample,
            maxNewTokens: maxNewTokens
        )
        // Voice cloning fields for Base models
        if supportsReferenceVoice, let refURL = referenceAudioURL {
            opts.referenceAudioPath = refURL.path
            opts.referenceText = referenceText
            opts.xVectorOnlyMode = xVectorOnlyMode
            opts.subtalkerTemperature = subtalkerTemperature
            opts.subtalkerTopK = subtalkerTopK
            opts.subtalkerTopP = subtalkerTopP
            opts.subtalkerDoSample = subtalkerDoSample
        }
        return opts
    }

    private let ttsService: any TTSService
    private let notificationService: any NotificationService
    var provider: TTSProvider
    var apiURL: String
    var apiPort: Int
    private var synthesisTask: Task<Void, Never>?

    init(project: VoiceoverProject, ttsService: any TTSService, notificationService: any NotificationService) {
        self.ttsService = ttsService
        self.notificationService = notificationService
        self.speed = project.ttsSpeed
        self.pitch = project.ttsPitch
        self.emotion = project.ttsEmotion ?? ""
        self.provider = project.ttsProvider
        self.apiURL = project.apiURL
        self.apiPort = project.apiPort
        self.selectedModel = project.ttsModelName ?? ""

        // Восстановить расширенные настройки из проекта
        self.selectedSpeaker = project.ttsSpeaker ?? ""
        self.selectedLanguage = project.ttsLanguage ?? ""
        self.temperature = project.ttsTemperature ?? -1
        self.topK = project.ttsTopK ?? -1
        self.topP = project.ttsTopP ?? -1
        self.repetitionPenalty = project.ttsRepetitionPenalty ?? -1
        self.doSample = project.ttsDoSample ?? true
        self.maxNewTokens = project.ttsMaxNewTokens ?? -1

        // Восстановить reference audio и subtalker
        self.xVectorOnlyMode = project.ttsXVectorOnlyMode ?? false
        self.subtalkerTemperature = project.ttsSubtalkerTemperature ?? -1
        self.subtalkerTopK = project.ttsSubtalkerTopK ?? -1
        self.subtalkerTopP = project.ttsSubtalkerTopP ?? -1
        self.subtalkerDoSample = project.ttsSubtalkerDoSample ?? true
        self.referenceText = project.ttsReferenceText ?? ""
        if let bookmarkData = project.ttsReferenceAudioBookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if url.startAccessingSecurityScopedResource() {
                    self.referenceAudioURL = url
                }
            }
        }
    }

    /// Обновить провайдер и API-параметры из проекта (вызывается при переходе на шаг 3)
    func updateFromProject(_ project: VoiceoverProject) {
        let providerChanged = provider != project.ttsProvider
        provider = project.ttsProvider
        apiURL = project.apiURL
        apiPort = project.apiPort

        if providerChanged {
            // Сбросить модель и список при смене провайдера
            selectedModel = project.ttsModelName ?? ""
            availableModels = []
            errorMessage = nil
        }
    }

    func loadModels() async {
        isLoadingModels = true
        do {
            availableModels = try await ttsService.availableModels(
                provider: provider,
                apiURL: apiURL,
                apiPort: apiPort
            )
            if selectedModel.isEmpty, let first = availableModels.first {
                selectedModel = first
            }
        } catch {
            errorMessage = "Не удалось загрузить модели: \(error.localizedDescription)"
        }
        isLoadingModels = false
    }

    func prepareSegments(_ texts: [String]) {
        segmentStates = texts.enumerated().map { index, text in
            SegmentSynthesisState(
                id: index,
                index: index,
                fullText: text,
                previewText: String(text.prefix(80))
            )
        }
        totalSegments = segmentStates.count
    }

    func synthesizeAll() async {
        guard !selectedModel.isEmpty else {
            errorMessage = "Пожалуйста, выберите модель"
            return
        }

        isSynthesizing = true
        progress = 0
        errorMessage = nil

        let segments = segmentStates.map { state in
            (index: state.index, text: state.fullText)
        }

        do {
            let outputDir = AppConstants.tempAudioDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            synthesisTask = Task {
                do {
                    let urls = try await ttsService.synthesizeBatch(
                        segments: segments,
                        modelName: selectedModel,
                        provider: provider,
                        speed: speed,
                        pitch: pitch,
                        emotion: emotion.isEmpty ? nil : emotion,
                        apiURL: apiURL,
                        apiPort: apiPort,
                        outputDirectory: outputDir,
                        options: generationOptions,
                        progressHandler: { [weak self] prog in
                            guard let self else { return }
                            Task { @MainActor in
                                self.progress = prog
                                let completedCount = Int(prog * Double(segments.count))
                                self.currentSegmentIndex = min(completedCount, segments.count - 1)
                                for i in 0..<self.segmentStates.count {
                                    if i < completedCount {
                                        self.segmentStates[i].status = .completed
                                    } else if i == completedCount && i < self.segmentStates.count {
                                        self.segmentStates[i].status = .inProgress
                                    }
                                }
                            }
                        }
                    )

                    for (i, url) in urls.enumerated() {
                        if i < segmentStates.count {
                            segmentStates[i].status = .completed
                            segmentStates[i].audioURL = url
                        }
                    }
                    await notificationService.send(
                        title: "Озвучка готова",
                        body: "\(segments.count) сегментов синтезировано"
                    )
                } catch {
                    errorMessage = error.localizedDescription
                    await notificationService.send(
                        title: "Ошибка озвучки",
                        body: error.localizedDescription
                    )
                }
                isSynthesizing = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isSynthesizing = false
        }
    }

    func cancelSynthesis() async {
        synthesisTask?.cancel()
        await ttsService.cancel()
        isSynthesizing = false
    }

    func previewSegment(_ index: Int) async {
        // Audio preview handled by AudioPlayerViewModel
    }

    /// Выбрать файл с образцом голоса для клонирования (Base-модели)
    func importReferenceAudio() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        panel.message = "Выберите аудиозапись с образцом голоса (от 3 секунд)"
        if panel.runModal() == .OK, let url = panel.url {
            referenceAudioURL = url
        }
    }

    func saveToProject(_ project: VoiceoverProject) {
        project.ttsModelName = selectedModel
        project.ttsSpeed = speed
        project.ttsPitch = pitch
        project.ttsEmotion = emotion.isEmpty ? nil : emotion
        // Расширенные параметры
        project.ttsSpeaker = selectedSpeaker.isEmpty ? nil : selectedSpeaker
        project.ttsLanguage = selectedLanguage.isEmpty ? nil : selectedLanguage
        project.ttsTemperature = temperature
        project.ttsTopK = topK
        project.ttsTopP = topP
        project.ttsRepetitionPenalty = repetitionPenalty
        project.ttsDoSample = doSample
        project.ttsMaxNewTokens = maxNewTokens > 0 ? maxNewTokens : nil
        // Voice cloning reference
        if let refURL = referenceAudioURL {
            project.ttsReferenceAudioBookmark = try? refURL.bookmarkData(options: .withSecurityScope)
        } else {
            project.ttsReferenceAudioBookmark = nil
        }
        project.ttsReferenceText = referenceText.isEmpty ? nil : referenceText
        project.ttsXVectorOnlyMode = xVectorOnlyMode
        project.ttsSubtalkerTemperature = subtalkerTemperature > 0 ? subtalkerTemperature : nil
        project.ttsSubtalkerTopK = subtalkerTopK > 0 ? subtalkerTopK : nil
        project.ttsSubtalkerTopP = subtalkerTopP > 0 ? subtalkerTopP : nil
        project.ttsSubtalkerDoSample = subtalkerDoSample
        project.updatedAt = Date()
    }
}
