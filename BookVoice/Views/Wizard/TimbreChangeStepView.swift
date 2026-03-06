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

    /// Только готовые к использованию голоса
    private var readyProfiles: [VoiceProfile] {
        voiceProfiles.filter(\.isReady)
    }

    /// Выбран ли голос из библиотеки
    private var hasSelectedProfile: Bool {
        viewModel.selectedVoiceProfileId != nil
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Изменение тембра голоса")
                    .font(.title2.bold())
                Spacer()
                Toggle("Включить", isOn: $viewModel.isEnabled)
                    .toggleStyle(.switch)
            }

            if viewModel.isEnabled {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Voice profile from library
                        if !readyProfiles.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Голос из библиотеки")
                                    .font(.headline)
                                Picker("Голос", selection: $viewModel.selectedVoiceProfileId) {
                                    Text("Не выбран").tag(UUID?.none)
                                    ForEach(readyProfiles) { profile in
                                        Text(profile.name).tag(Optional(profile.id))
                                    }
                                }
                                .labelsHidden()
                                .onChange(of: viewModel.selectedVoiceProfileId) { _, newValue in
                                    if let id = newValue,
                                       let profile = readyProfiles.first(where: { $0.id == id }) {
                                        viewModel.selectVoiceProfile(profile)
                                    }
                                }
                            }

                            Divider()
                        }

                        // RVC Model (manual) — only when NO library profile selected
                        if !hasSelectedProfile {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Или выберите файл голоса вручную")
                                    .font(.headline)
                                HStack {
                                    if viewModel.isLoadingModels {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Ищу сохранённые голоса\u{2026}")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Picker("Голос", selection: $viewModel.modelPath) {
                                            if viewModel.availableModels.isEmpty {
                                                Text("Выберите файл через \u{00AB}Обзор\u{00BB}").tag("")
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
                                if viewModel.availableModels.isEmpty && !viewModel.isLoadingModels {
                                    Text("Если у вас нет файла голоса, сначала создайте его в разделе \u{00AB}Голоса\u{00BB} на боковой панели.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()
                        }

                        // Parameters (collapsible)
                        DisclosureGroup("Параметры") {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Text("Индекс")
                                        .font(.callout)
                                        .frame(width: 130, alignment: .leading)
                                    Slider(value: $viewModel.indexRate, in: 0...1, step: 0.05)
                                    Text("\(viewModel.indexRate, specifier: "%.2f")")
                                        .font(.callout.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 36, alignment: .trailing)
                                }

                                HStack(spacing: 12) {
                                    Text("Радиус фильтра")
                                        .font(.callout)
                                        .frame(width: 130, alignment: .leading)
                                    Slider(
                                        value: Binding(
                                            get: { Double(viewModel.filterRadius) },
                                            set: { viewModel.filterRadius = Int($0) }
                                        ),
                                        in: 0...7,
                                        step: 1
                                    )
                                    Text("\(viewModel.filterRadius)")
                                        .font(.callout.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 36, alignment: .trailing)
                                }

                                HStack(spacing: 12) {
                                    Text("Защита безгласных")
                                        .font(.callout)
                                        .frame(width: 130, alignment: .leading)
                                    Slider(value: $viewModel.protectVoiceless, in: 0...0.5, step: 0.01)
                                    Text("\(viewModel.protectVoiceless, specifier: "%.2f")")
                                        .font(.callout.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 36, alignment: .trailing)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .font(.callout.weight(.medium))

                        Divider()

                        // Demo preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Демо-прослушивание")
                                .font(.headline)
                            Text("Примените изменение голоса к одному сегменту для проверки настроек")
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
                                        Text("Обработка\u{2026}")
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

                        // Progress — inside ScrollView so layout doesn't break
                        if viewModel.isConverting {
                            VStack(spacing: 4) {
                                HStack {
                                    Text("Конвертация аудио\u{2026}")
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

                        // Error — inside ScrollView so layout doesn't break
                        if let error = viewModel.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            } else {
                Spacer()
                ContentUnavailableView(
                    "Изменение голоса отключено",
                    systemImage: "waveform.slash",
                    description: Text("Включите переключатель выше, чтобы заменить голос озвучки на другой.")
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
