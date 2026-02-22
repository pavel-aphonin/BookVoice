//
//  WizardContainerView.swift
//  BookVoice
//

import SwiftUI

struct WizardContainerView: View {
    @State private var viewModel: WizardViewModel
    var onDismiss: () -> Void

    init(project: VoiceoverProject, services: ServiceContainer, onDismiss: @escaping () -> Void) {
        self._viewModel = State(initialValue: WizardViewModel(project: project, services: services))
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: Step indicator
            GlassStepper(
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
                    VoiceoverStepView(viewModel: viewModel.voiceover)
                case 4:
                    TimbreChangeStepView(viewModel: viewModel.timbreChange)
                case 5:
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
                Button("Cancel") {
                    viewModel.saveCurrentStepToProject()
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                if viewModel.canGoBack {
                    GlassButton(title: "Back", icon: "chevron.left") {
                        viewModel.goToPreviousStep()
                    }
                }

                if viewModel.isLastStep {
                    GlassButton(title: "Export", icon: "square.and.arrow.up.fill") {
                        viewModel.saveCurrentStepToProject()
                        Task {
                            let audioFiles = viewModel.voiceover.segmentStates.compactMap { $0.audioURL }
                            await viewModel.postProcessing.export(audioFiles: audioFiles)
                        }
                    }
                    .disabled(!viewModel.postProcessing.canExport)
                } else {
                    GlassButton(title: "Next", icon: "chevron.right") {
                        viewModel.goToNextStep()
                    }
                    .disabled(!viewModel.canGoForward)
                }
            }
            .padding(16)
        }
        .background(.ultraThinMaterial)
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
