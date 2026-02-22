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
                            Text("TTS Model")
                                .font(.headline)
                            if viewModel.isLoadingModels {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Picker("Model", selection: $viewModel.selectedModel) {
                                    if viewModel.availableModels.isEmpty {
                                        Text("No models available").tag("")
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
                            title: viewModel.isSynthesizing ? "Cancel" : "Synthesize All",
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
                            label: "Speed"
                        )

                        GlassSlider(
                            value: $viewModel.pitch,
                            range: 0.5...2.0,
                            step: 0.1,
                            label: "Pitch"
                        )

                        GlassTextField(
                            label: "Emotion",
                            text: $viewModel.emotion,
                            prompt: "e.g., neutral, happy"
                        )
                        .frame(maxWidth: 150)
                    }
                }
            }

            // Progress
            if viewModel.isSynthesizing {
                GlassProgressBar(
                    progress: viewModel.progress,
                    label: "Synthesizing segment \(viewModel.currentSegmentIndex + 1) of \(viewModel.totalSegments)..."
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
                            "No Segments",
                            systemImage: "text.line.first.and.arrowtriangle.forward",
                            description: Text("Load text in the previous step first.")
                        )
                    } else {
                        ForEach(viewModel.segmentStates) { state in
                            GlassPanel(padding: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: state.statusIcon)
                                        .foregroundStyle(state.statusColor)
                                        .frame(width: 20)

                                    Text("Segment \(state.index + 1)")
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
