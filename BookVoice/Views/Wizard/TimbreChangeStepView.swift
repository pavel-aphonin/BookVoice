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
                Text("Изменение тембра (RVC)")
                    .font(.title2.bold())
                Spacer()
                Toggle("Включить RVC", isOn: $viewModel.isEnabled)
                    .toggleStyle(.switch)
            }

            if viewModel.isEnabled {
                GlassPanel(padding: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Model selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Модель RVC")
                                .font(.headline)

                            HStack {
                                if viewModel.isLoadingModels {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Picker("Model", selection: $viewModel.modelPath) {
                                        if viewModel.availableModels.isEmpty {
                                            Text("Нет доступных моделей").tag("")
                                        }
                                        ForEach(viewModel.availableModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .labelsHidden()
                                }

                                GlassButton(title: "Обзор", icon: "folder") {
                                    viewModel.browseModel()
                                }
                            }
                        }

                        Divider()

                        // Parameters
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Параметры")
                                .font(.headline)

                            GlassSlider(
                                value: $viewModel.indexRate,
                                range: 0...1,
                                step: 0.05,
                                label: "Индекс"
                            )

                            GlassIntSlider(
                                value: $viewModel.filterRadius,
                                range: 0...7,
                                label: "Радиус фильтра"
                            )

                            GlassSlider(
                                value: $viewModel.protectVoiceless,
                                range: 0...0.5,
                                step: 0.01,
                                label: "Защита безгласных",
                                format: "%.2f"
                            )
                        }

                        Divider()

                        // Voice sample
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Образец голоса (необязательно)")
                                .font(.headline)
                            Text("Загрузите референсный аудиофайл для клонирования голоса")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                if let url = viewModel.voiceSampleURL {
                                    Label(url.lastPathComponent, systemImage: "waveform")
                                        .font(.subheadline)
                                } else {
                                    Text("Образец не выбран")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                GlassButton(title: "Выбрать", icon: "waveform.badge.plus") {
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
                        label: "Конвертация аудио..."
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
                    "RVC отключён",
                    systemImage: "waveform.slash",
                    description: Text("Включите RVC, чтобы изменить тембр голоса аудиокниги.")
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
