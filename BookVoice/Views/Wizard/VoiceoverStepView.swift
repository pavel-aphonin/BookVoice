//
//  VoiceoverStepView.swift
//  BookVoice
//

import SwiftUI

struct VoiceoverStepView: View {
    @Bindable var viewModel: VoiceoverViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Top controls
            GroupBox {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TTS-модель")
                                .font(.headline)
                            if viewModel.isLoadingModels {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Picker("Модель", selection: $viewModel.selectedModel) {
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

                        Button {
                            if viewModel.isSynthesizing {
                                Task { await viewModel.cancelSynthesis() }
                            } else {
                                Task { await viewModel.synthesizeAll() }
                            }
                        } label: {
                            Label(
                                viewModel.isSynthesizing ? "Отмена" : "Озвучить всё",
                                systemImage: viewModel.isSynthesizing ? "stop.fill" : "waveform"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedModel.isEmpty && !viewModel.isSynthesizing)
                    }

                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Скорость: \(viewModel.speed, specifier: "%.1f")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $viewModel.speed, in: 0.5...2.0, step: 0.1)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Высота тона: \(viewModel.pitch, specifier: "%.1f")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $viewModel.pitch, in: 0.5...2.0, step: 0.1)
                        }

                        TextField("Эмоция", text: $viewModel.emotion, prompt: Text("напр., нейтральная"))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 150)
                    }
                }
            }

            // Progress
            if viewModel.isSynthesizing {
                VStack(spacing: 4) {
                    HStack {
                        Text("Синтез сегмента \(viewModel.currentSegmentIndex + 1) из \(viewModel.totalSegments)...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(viewModel.progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: viewModel.progress)
                }
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            // Segment list
            if viewModel.segmentStates.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "Нет сегментов",
                    systemImage: "text.line.first.and.arrowtriangle.forward",
                    description: Text("Сначала загрузите текст на предыдущем шаге.")
                )
                Spacer()
            } else {
                List(viewModel.segmentStates) { state in
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
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
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
