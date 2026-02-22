//
//  VoiceoverStepView.swift
//  BookVoice
//

import SwiftUI

struct VoiceoverStepView: View {
    @Bindable var viewModel: VoiceoverViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Top controls
            GlassPanel(padding: 16) {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TTS-модель")
                                .font(.headline)
                            if viewModel.isLoadingModels {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Picker("Model", selection: $viewModel.selectedModel) {
                                    if viewModel.availableModels.isEmpty {
                                        Text("Нет доступных моделей").tag("")
                                    }
                                    ForEach(viewModel.availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .labelsHidden()
                                .frame(minWidth: 200)
                            }
                        }

                        Spacer()

                        GlassButton(
                            title: viewModel.isSynthesizing ? "Отмена" : "Озвучить всё",
                            icon: viewModel.isSynthesizing ? "stop.fill" : "waveform"
                        ) {
                            if viewModel.isSynthesizing {
                                Task { await viewModel.cancelSynthesis() }
                            } else {
                                Task { await viewModel.synthesizeAll() }
                            }
                        }
                        .disabled(viewModel.selectedModel.isEmpty && !viewModel.isSynthesizing)
                    }

                    HStack(spacing: 24) {
                        GlassSlider(
                            value: $viewModel.speed,
                            range: 0.5...2.0,
                            step: 0.1,
                            label: "Скорость"
                        )

                        GlassSlider(
                            value: $viewModel.pitch,
                            range: 0.5...2.0,
                            step: 0.1,
                            label: "Высота тона"
                        )

                        GlassTextField(
                            label: "Эмоция",
                            text: $viewModel.emotion,
                            prompt: "напр., нейтральная, радостная"
                        )
                        .frame(maxWidth: 150)
                    }
                }
            }

            // Progress
            if viewModel.isSynthesizing {
                GlassProgressBar(
                    progress: viewModel.progress,
                    label: "Синтез сегмента \(viewModel.currentSegmentIndex + 1) из \(viewModel.totalSegments)..."
                )
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            // Segment list
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.segmentStates.isEmpty {
                        ContentUnavailableView(
                            "Нет сегментов",
                            systemImage: "text.line.first.and.arrowtriangle.forward",
                            description: Text("Сначала загрузите текст на предыдущем шаге.")
                        )
                    } else {
                        ForEach(viewModel.segmentStates) { state in
                            GlassPanel(padding: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: state.statusIcon)
                                        .foregroundStyle(state.statusColor)
                                        .frame(width: 20)

                                    Text("Сегмент \(state.index + 1)")
                                        .font(.subheadline.bold())
                                        .frame(width: 80, alignment: .leading)

                                    Text(state.previewText)
                                        .lineLimit(1)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)

                                    Spacer()

                                    if state.isCompleted {
                                        Button {
                                            Task { await viewModel.previewSegment(state.index) }
                                        } label: {
                                            Image(systemName: "play.circle")
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            if viewModel.availableModels.isEmpty {
                await viewModel.loadModels()
            }
        }
    }
}

#Preview {
    VoiceoverStepView(
        viewModel: VoiceoverViewModel(
            project: VoiceoverProject(title: "Test"),
            ttsService: MockTTSService()
        )
    )
    .frame(width: 700, height: 500)
    .padding()
}
