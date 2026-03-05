//
//  WizardContainerView.swift
//  BookVoice
//

import SwiftUI

struct WizardContainerView: View {
    @State private var viewModel: WizardViewModel
    @State private var showExitConfirmation = false
    var onDismiss: () -> Void

    init(project: VoiceoverProject, services: ServiceContainer, onDismiss: @escaping () -> Void) {
        self._viewModel = State(initialValue: WizardViewModel(project: project, services: services))
        self.onDismiss = onDismiss
    }

    /// Есть ли данные, которые могут быть потеряны
    private var hasUnsavedWork: Bool {
        viewModel.currentStep > 1
            || !viewModel.modelSettings.systemPrompt.isEmpty
            || viewModel.voiceover.segmentStates.contains(where: { $0.isCompleted })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: Step indicator
            StepIndicator(
                steps: viewModel.stepTitles,
                currentStep: viewModel.currentStep,
                onStepTapped: { step in viewModel.goToStep(step) }
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Divider().padding(.vertical, 8)

            // Center: Step content
            Group {
                switch viewModel.currentStep {
                case 1:
                    ModelSettingsStepView(viewModel: viewModel.modelSettings)
                case 2:
                    TextUploadStepView(viewModel: viewModel.textUpload)
                case 3:
                    TextPreprocessingStepView(viewModel: viewModel.textPreprocessing)
                case 4:
                    VoiceoverStepView(viewModel: viewModel.voiceover)
                case 5:
                    TimbreChangeStepView(viewModel: viewModel.timbreChange)
                case 6:
                    PostProcessingStepView(viewModel: viewModel.postProcessing)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(viewModel.currentStep)

            Divider()

            // Bottom: Navigation buttons
            HStack {
                Button("Закрыть") {
                    if hasUnsavedWork {
                        showExitConfirmation = true
                    } else {
                        viewModel.saveCurrentStepToProject()
                        onDismiss()
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                if viewModel.canGoBack {
                    Button {
                        viewModel.goToPreviousStep()
                    } label: {
                        Label("Назад", systemImage: "chevron.left")
                    }
                }

                if viewModel.isLastStep {
                    Button {
                        viewModel.saveCurrentStepToProject()
                        Task {
                            await viewModel.postProcessing.export(audioFiles: viewModel.finalAudioURLs)
                        }
                    } label: {
                        Label("Экспорт", systemImage: "square.and.arrow.up.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.postProcessing.canExport || viewModel.finalAudioURLs.isEmpty)
                } else {
                    Button {
                        viewModel.goToNextStep()
                    } label: {
                        Label("Далее", systemImage: "chevron.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canGoForward)
                }
            }
            .padding(16)
        }
        .alert("Выйти из мастера?", isPresented: $showExitConfirmation) {
            Button("Остаться", role: .cancel) {}
            Button("Сохранить и выйти") {
                viewModel.saveCurrentStepToProject()
                onDismiss()
            }
            Button("Выйти без сохранения", role: .destructive) {
                onDismiss()
            }
        } message: {
            Text("Ваш прогресс будет сохранён, и вы сможете продолжить позже. Если выйдете без сохранения, несохранённые изменения будут потеряны.")
        }
    }
}

#Preview {
    WizardContainerView(
        project: VoiceoverProject(title: "Test Book"),
        services: .mock,
        onDismiss: {}
    )
    .frame(width: 900, height: 600)
}
