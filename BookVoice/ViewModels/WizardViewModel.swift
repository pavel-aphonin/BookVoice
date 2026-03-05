//
//  WizardViewModel.swift
//  BookVoice
//

import SwiftUI

@Observable
final class WizardViewModel {
    // Navigation
    var currentStep: Int = 1
    let totalSteps = 6

    // Child view models
    let modelSettings: ModelSettingsViewModel
    let textUpload: TextUploadViewModel
    let textPreprocessing: TextPreprocessingViewModel
    let voiceover: VoiceoverViewModel
    let timbreChange: TimbreChangeViewModel
    let postProcessing: PostProcessingViewModel

    // The project being edited
    let project: VoiceoverProject

    let stepTitles = ["Модель", "Текст", "Подготовка", "Озвучка", "Тембр", "Экспорт"]

    var canGoBack: Bool { currentStep > 1 }

    var canGoForward: Bool {
        switch currentStep {
        case 1: return modelSettings.isValid
        case 2: return textUpload.isValid
        case 3: return textPreprocessing.isValid && !textPreprocessing.isProcessing
        case 4: return voiceover.isReady && !voiceover.isSynthesizing
        case 5: return timbreChange.isValid && !timbreChange.isConverting
        case 6: return false
        default: return false
        }
    }

    var isLastStep: Bool { currentStep == totalSteps }

    /// Финальные аудиофайлы для экспорта: RVC-конвертированные (если включены) или TTS-оригиналы
    var finalAudioURLs: [URL] {
        if timbreChange.isEnabled && !timbreChange.convertedAudioURLs.isEmpty {
            return timbreChange.convertedAudioURLs
        }
        return voiceover.segmentStates.compactMap { $0.audioURL }
    }

    init(project: VoiceoverProject, services: ServiceContainer) {
        self.project = project
        self.currentStep = max(1, project.currentStep)

        self.modelSettings = ModelSettingsViewModel(
            project: project,
            ttsService: services.tts
        )
        self.textUpload = TextUploadViewModel(
            project: project,
            textService: services.textProcessing
        )
        self.textPreprocessing = TextPreprocessingViewModel(
            project: project,
            llmService: services.llm
        )
        self.voiceover = VoiceoverViewModel(
            project: project,
            ttsService: services.tts,
            notificationService: services.notification
        )
        self.timbreChange = TimbreChangeViewModel(
            project: project,
            rvcService: services.rvc,
            modelManager: services.modelManager,
            audioEngine: services.audioEngine,
            notificationService: services.notification
        )
        self.postProcessing = PostProcessingViewModel(
            project: project,
            audioEngine: services.audioEngine,
            notificationService: services.notification
        )
    }

    func goToNextStep() {
        guard canGoForward, currentStep < totalSteps else { return }
        saveCurrentStepToProject()

        withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
            currentStep += 1
        }
        project.currentStep = currentStep

        // Prepare next step data
        Task {
            await prepareStep(currentStep)
        }
    }

    func goToPreviousStep() {
        guard canGoBack else { return }
        withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
            currentStep -= 1
        }
    }

    func goToStep(_ step: Int) {
        guard step >= 1, step <= totalSteps else { return }
        guard step <= project.currentStep || step <= currentStep else { return }
        withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
            currentStep = step
        }
    }

    func saveCurrentStepToProject() {
        switch currentStep {
        case 1: modelSettings.saveToProject(project)
        case 2: textUpload.saveToProject(project)
        case 3: textPreprocessing.saveToProject(project)
        case 4: voiceover.saveToProject(project)
        case 5: timbreChange.saveToProject(project)
        case 6: postProcessing.saveToProject(project)
        default: break
        }
    }

    private func prepareStep(_ step: Int) async {
        switch step {
        case 3:
            // Подготовить сегменты из шага 2 для LLM-обработки
            let segments = await textUpload.allSegments()
            textPreprocessing.prepareSegments(segments)
        case 4:
            // Обновить провайдер/API из проекта (мог измениться на шаге 1)
            voiceover.updateFromProject(project)
            await voiceover.loadModels()
            // Передать сегменты через шаг подготовки текста (обработанные или оригинальные)
            voiceover.prepareSegments(textPreprocessing.outputSegments)
        case 5:
            await timbreChange.loadModels()
            // Передать TTS-аудио для RVC-конвертации
            timbreChange.audioSegmentURLs = voiceover.segmentStates.compactMap { $0.audioURL }
        default:
            break
        }
    }
}
