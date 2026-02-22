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
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // RVC Model
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Модель RVC")
                                .font(.headline)
                            HStack {
                                if viewModel.isLoadingModels {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Picker("Модель", selection: $viewModel.modelPath) {
                                        if viewModel.availableModels.isEmpty {
                                            Text("Нет доступных моделей").tag("")
                                        }
                                        ForEach(viewModel.availableModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .labelsHidden()
                                }

                                Button {
                                    viewModel.browseModel()
                                } label: {
                                    Label("Обзор", systemImage: "folder")
                                }
                            }
                        }

                        Divider()

                        // Parameters
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Параметры")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Индекс: \(viewModel.indexRate, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Slider(value: $viewModel.indexRate, in: 0...1, step: 0.05)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Радиус фильтра: \(viewModel.filterRadius)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Slider(
                                    value: Binding(
                                        get: { Double(viewModel.filterRadius) },
                                        set: { viewModel.filterRadius = Int($0) }
                                    ),
                                    in: 0...7,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Защита безгласных: \(viewModel.protectVoiceless, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Slider(value: $viewModel.protectVoiceless, in: 0...0.5, step: 0.01)
                            }
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

                                Button {
                                    viewModel.browseVoiceSample()
                                } label: {
                                    Label("Выбрать", systemImage: "waveform.badge.plus")
                                }
                            }
                        }
                    }
                }

                // Progress
                if viewModel.isConverting {
                    VStack(spacing: 4) {
                        HStack {
                            Text("Конвертация аудио...")
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
