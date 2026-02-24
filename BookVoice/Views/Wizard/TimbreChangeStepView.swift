//
//  TimbreChangeStepView.swift
//  BookVoice
//

import SwiftUI
import SwiftData

struct TimbreChangeStepView: View {
    @Bindable var viewModel: TimbreChangeViewModel
    @Query(sort: \VoiceProfile.createdAt, order: .reverse)
    private var voiceProfiles: [VoiceProfile]

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
                        // Voice profile from library
                        if !voiceProfiles.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Голос из библиотеки")
                                    .font(.headline)
                                Picker("Голос", selection: $viewModel.selectedVoiceProfileId) {
                                    Text("Не выбран").tag(UUID?.none)
                                    ForEach(voiceProfiles) { profile in
                                        Text(profile.name).tag(Optional(profile.id))
                                    }
                                }
                                .labelsHidden()
                                .onChange(of: viewModel.selectedVoiceProfileId) { _, newValue in
                                    if let id = newValue,
                                       let profile = voiceProfiles.first(where: { $0.id == id }) {
                                        viewModel.selectVoiceProfile(profile)
                                    }
                                }
                            }

                            Divider()
                        }

                        // RVC Model (manual)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Или выберите модель вручную")
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

                        Divider()

                        // Demo preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Демо-прослушивание")
                                .font(.headline)
                            Text("Примените RVC к одному сегменту для проверки настроек")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                if viewModel.audioSegmentURLs.count > 1 {
                                    Picker("Сегмент", selection: $viewModel.demoSegmentIndex) {
                                        ForEach(0..<viewModel.audioSegmentURLs.count, id: \.self) { i in
                                            Text("Сегмент \(i + 1)").tag(i)
                                        }
                                    }
                                    .frame(maxWidth: 150)
                                }

                                Button {
                                    Task { await viewModel.previewDemo() }
                                } label: {
                                    if viewModel.isDemoProcessing {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Обработка...")
                                    } else {
                                        Label("Прослушать демо", systemImage: "play.fill")
                                    }
                                }
                                .disabled(
                                    viewModel.isDemoProcessing ||
                                    viewModel.modelPath.isEmpty ||
                                    viewModel.audioSegmentURLs.isEmpty
                                )

                                Button {
                                    Task { await viewModel.stopDemo() }
                                } label: {
                                    Image(systemName: "stop.fill")
                                }

                                if viewModel.audioSegmentURLs.isEmpty {
                                    Text("Сначала выполните озвучку (шаг 3)")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
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
            modelManager: MockModelManagerService(),
            audioEngine: MockAudioEngineService(),
            notificationService: MockNotificationService()
        )
    )
    .frame(width: 700, height: 500)
    .padding()
}
