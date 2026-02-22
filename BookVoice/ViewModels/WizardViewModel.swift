//
//  WizardViewModel.swift
//  BookVoice
//

import SwiftUI

@Observable
final class WizardViewModel {
    // Navigation
    var currentStep: Int = 1
    let totalSteps = 5

    // Child view models
    let modelSettings: ModelSettingsViewModel
    let textUpload: TextUploadViewModel
    let voiceover: VoiceoverViewModel
    let timbreChange: TimbreChangeViewModel
    let postProcessing: PostProcessingViewModel

    // The project being edited
    let project: VoiceoverProject

    let stepTitles = ["Модель", "Текст", "Озвучка", "Тембр", "Экспорт"]

    var canGoBack: Bool { currentStep > 1 }

    var canGoForward: Bool {
        switch currentStep {
        case 1: return modelSettings.isValid
        case 2: return textUpload.isValid
        case 3: return true
        case 4: return timbreChange.isValid
        case 5: return false
        default: return false
        }
    }

    var isLastStep: Bool { currentStep == totalSteps }

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
        self.voiceover = VoiceoverViewModel(
            project: project,
            ttsService: services.tts
        )
        self.timbreChange = TimbreChangeViewModel(
            project: project,
            rvcService: services.rvc,
            modelManager: services.modelManager
        )
        self.postProcessing = PostProcessingViewModel(
            project: project,
            audioEngine: services.audioEngine
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
        case 3: voiceover.saveToProject(project)
        case 4: timbreChange.saveToProject(project)
        case 5: postProcessing.saveToProject(project)
        default: break
        }
    }

    private func prepareStep(_ step: Int) async {
        switch step {
        case 3:
            await voiceover.loadModels()
            let segments = await textUpload.allSegments()
            voiceover.prepareSegments(segments)
        case 4:
            await timbreChange.loadModels()
        default:
            break
        }
    }
}
