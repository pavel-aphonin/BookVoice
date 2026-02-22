//
//  TimbreChangeStepView.swift
//  BookVoice
//

import SwiftUI

struct TimbreChangeStepView: View {
    @Bindable var viewModel: TimbreChangeViewModel

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Timbre Change (RVC)")
                    .font(.title2.bold())
                Spacer()
                Toggle("Enable RVC", isOn: $viewModel.isEnabled)
                    .toggleStyle(.switch)
            }

            if viewModel.isEnabled {
                GlassPanel(padding: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Model selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RVC Model")
                                .font(.headline)

                            HStack {
                                if viewModel.isLoadingModels {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Picker("Model", selection: $viewModel.modelPath) {
                                        if viewModel.availableModels.isEmpty {
                                            Text("No models available").tag("")
                                        }
                                        ForEach(viewModel.availableModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .labelsHidden()
                                }

                                GlassButton(title: "Browse", icon: "folder") {
                                    viewModel.browseModel()
                                }
                            }
                        }

                        Divider()

                        // Parameters
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Parameters")
                                .font(.headline)

                            GlassSlider(
                                value: $viewModel.indexRate,
                                range: 0...1,
                                step: 0.05,
                                label: "Index Rate"
                            )

                            GlassIntSlider(
                                value: $viewModel.filterRadius,
                                range: 0...7,
                                label: "Filter Radius"
                            )

                            GlassSlider(
                                value: $viewModel.protectVoiceless,
                                range: 0...0.5,
                                step: 0.01,
                                label: "Protect Voiceless",
                                format: "%.2f"
                            )
                        }

                        Divider()

                        // Voice sample
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Voice Sample (Optional)")
                                .font(.headline)
                            Text("Upload a reference audio file for voice cloning")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                if let url = viewModel.voiceSampleURL {
                                    Label(url.lastPathComponent, systemImage: "waveform")
                                        .font(.subheadline)
                                } else {
                                    Text("No sample selected")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                GlassButton(title: "Select", icon: "waveform.badge.plus") {
                                    viewModel.browseVoiceSample()
                                }
                            }
                        }
                    }
                }

                // Progress
                if viewModel.isConverting {
                    GlassProgressBar(
                        progress: viewModel.progress,
                        label: "Converting audio..."
                    )
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            } else {
                Spacer()
                ContentUnavailableView(
                    "RVC Disabled",
                    systemImage: "waveform.slash",
                    description: Text("Enable RVC to change the voice timbre of your audiobook.")
                )
                Spacer()
            }

            Spacer()
        }
        .task {
            if viewModel.isEnabled && viewModel.availableModels.isEmpty {
                await viewModel.loadModels()
            }
        }
    }
}

#Preview {
    TimbreChangeStepView(
        viewModel: TimbreChangeViewModel(
            project: VoiceoverProject(title: "Test"),
            rvcService: MockRVCService(),
            modelManager: MockModelManagerService()
        )
    )
    .frame(width: 700, height: 500)
    .padding()
}
