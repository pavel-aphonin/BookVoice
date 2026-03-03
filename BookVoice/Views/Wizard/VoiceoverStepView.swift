//
//  VoiceoverStepView.swift
//  BookVoice
//

import SwiftUI

struct VoiceoverStepView: View {
    @Bindable var viewModel: VoiceoverViewModel

    private let labelWidth: CGFloat = 130

    var body: some View {
        VStack(spacing: 16) {
            // Header: model picker + action button
            HStack(spacing: 12) {
                Text("Модель")
                    .font(.headline)

                if viewModel.isLoadingModels {
                    ProgressView()
                        .controlSize(.small)
                    Text("Загрузка\u{2026}")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Модель", selection: $viewModel.selectedModel) {
                        if viewModel.availableModels.isEmpty {
                            Text("Нет доступных моделей").tag("")
                        }
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 250)
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
                        viewModel.isSynthesizing ? "Остановить" : "Озвучить всё",
                        systemImage: viewModel.isSynthesizing ? "stop.fill" : "waveform"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    (viewModel.selectedModel.isEmpty && !viewModel.isSynthesizing)
                    || (viewModel.supportsReferenceVoice && viewModel.referenceAudioURL == nil && !viewModel.isSynthesizing)
                )
            }

            // --- Настройки голоса ---
            DisclosureGroup("Голос и стиль") {
                VStack(spacing: 12) {
                    // === Образец голоса для клонирования (Base-модели) ===
                    if viewModel.supportsReferenceVoice {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Text("Образец голоса")
                                    .font(.callout)
                                    .frame(width: labelWidth, alignment: .leading)

                                if let url = viewModel.referenceAudioURL {
                                    Label(url.lastPathComponent, systemImage: "waveform")
                                        .font(.callout)
                                        .lineLimit(1)
                                } else {
                                    Text("Не выбран")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    viewModel.importReferenceAudio()
                                } label: {
                                    Label("Выбрать", systemImage: "folder")
                                }
                                .controlSize(.small)
                            }

                            HStack(spacing: 12) {
                                Text("Текст образца")
                                    .font(.callout)
                                    .frame(width: labelWidth, alignment: .leading)
                                TextField(
                                    "",
                                    text: $viewModel.referenceText,
                                    prompt: Text("Расшифровка того, что говорит диктор"),
                                    axis: .vertical
                                )
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                            }

                            Toggle("Быстрый режим (x-vector only)", isOn: $viewModel.xVectorOnlyMode)
                                .font(.callout)
                                .help("Быстрее, но менее точное клонирование голоса")
                        }

                        Divider()
                    }

                    // === Спикер (CustomVoice + Silero) ===
                    if viewModel.supportsSpeakerSelection {
                        HStack(spacing: 12) {
                            Text("Спикер")
                                .font(.callout)
                                .frame(width: labelWidth, alignment: .leading)
                            Picker("Спикер", selection: $viewModel.selectedSpeaker) {
                                Text("Авто").tag("")
                                ForEach(viewModel.availableSpeakers, id: \.self) { speaker in
                                    Text(speaker).tag(speaker)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }

                    // === Язык (все локальные Qwen-модели) ===
                    if viewModel.supportsLanguageSelection {
                        HStack(spacing: 12) {
                            Text("Язык")
                                .font(.callout)
                                .frame(width: labelWidth, alignment: .leading)
                            Picker("Язык", selection: $viewModel.selectedLanguage) {
                                Text("Авто").tag("")
                                ForEach(viewModel.availableLanguages, id: \.self) { lang in
                                    Text(lang.localizedCapitalized).tag(lang)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }

                    // === Инструкция (CustomVoice — стиль чтения) ===
                    if viewModel.supportsEmotion {
                        HStack(spacing: 12) {
                            Text("Инструкция")
                                .font(.callout)
                                .frame(width: labelWidth, alignment: .leading)
                            TextField(
                                "",
                                text: $viewModel.emotion,
                                prompt: Text("напр., Читай спокойно и выразительно")
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                    }

                    // === Описание голоса (VoiceDesign) ===
                    if viewModel.supportsVoiceDescription {
                        HStack(spacing: 12) {
                            Text("Описание голоса")
                                .font(.callout)
                                .frame(width: labelWidth, alignment: .leading)
                            TextField(
                                "",
                                text: $viewModel.emotion,
                                prompt: Text("напр., Тёплый мужской голос, баритон, спокойный")
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Скорость
                    HStack(spacing: 12) {
                        Text("Скорость")
                            .font(.callout)
                            .frame(width: labelWidth, alignment: .leading)
                        Slider(value: $viewModel.speed, in: 0.5...2.0, step: 0.1)
                        Text("\(viewModel.speed, specifier: "%.1f")")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                    }

                    // Высота тона (Silero)
                    if !viewModel.supportsAdvancedOptions {
                        HStack(spacing: 12) {
                            Text("Высота тона")
                                .font(.callout)
                                .frame(width: labelWidth, alignment: .leading)
                            Slider(value: $viewModel.pitch, in: 0.5...2.0, step: 0.1)
                            Text("\(viewModel.pitch, specifier: "%.1f")")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .font(.callout.weight(.medium))

            // --- Расширенные параметры генерации (Qwen) ---
            if viewModel.supportsAdvancedOptions {
                DisclosureGroup("Параметры генерации") {
                    VStack(spacing: 12) {
                        // Temperature
                        parameterRow(
                            label: "Temperature",
                            hint: "Случайность (ниже = стабильнее)",
                            value: Binding(
                                get: { viewModel.temperature > 0 ? viewModel.temperature : 0.9 },
                                set: { viewModel.temperature = $0 }
                            ),
                            range: 0.1...1.5,
                            step: 0.05,
                            format: "%.2f"
                        )

                        // Top-K
                        intParameterRow(
                            label: "Top-K",
                            hint: "Ограничение выбора токенов",
                            value: Binding(
                                get: { viewModel.topK > 0 ? viewModel.topK : 50 },
                                set: { viewModel.topK = $0 }
                            ),
                            range: 1...200,
                            step: 1
                        )

                        // Top-P
                        parameterRow(
                            label: "Top-P",
                            hint: "Nucleus sampling",
                            value: Binding(
                                get: { viewModel.topP > 0 ? viewModel.topP : 1.0 },
                                set: { viewModel.topP = $0 }
                            ),
                            range: 0.1...1.0,
                            step: 0.05,
                            format: "%.2f"
                        )

                        // Repetition Penalty
                        parameterRow(
                            label: "Штраф повторов",
                            hint: "Меньше повторений в речи",
                            value: Binding(
                                get: { viewModel.repetitionPenalty > 0 ? viewModel.repetitionPenalty : 1.05 },
                                set: { viewModel.repetitionPenalty = $0 }
                            ),
                            range: 1.0...2.0,
                            step: 0.05,
                            format: "%.2f"
                        )

                        // Max New Tokens
                        intParameterRow(
                            label: "Max Tokens",
                            hint: "Макс. длина аудио (больше = длиннее)",
                            value: Binding(
                                get: { viewModel.maxNewTokens > 0 ? viewModel.maxNewTokens : 2048 },
                                set: { viewModel.maxNewTokens = $0 }
                            ),
                            range: 256...8192,
                            step: 256
                        )

                        // Do Sample toggle
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Сэмплирование")
                                    .font(.callout)
                                Text("Включить стохастическую генерацию")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(width: labelWidth, alignment: .leading)
                            Toggle("", isOn: $viewModel.doSample)
                                .labelsHidden()
                            Spacer()
                        }

                        // === Subtalker (только для Base-моделей — клонирование) ===
                        if viewModel.supportsReferenceVoice {
                            Divider()

                            Text("Параметры субталкера (клонирование)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            parameterRow(
                                label: "Sub Temperature",
                                hint: "Случайность эмбеддинга голоса",
                                value: Binding(
                                    get: { viewModel.subtalkerTemperature > 0 ? viewModel.subtalkerTemperature : 0.9 },
                                    set: { viewModel.subtalkerTemperature = $0 }
                                ),
                                range: 0.1...1.5,
                                step: 0.05,
                                format: "%.2f"
                            )

                            intParameterRow(
                                label: "Sub Top-K",
                                hint: "Top-K для эмбеддинга голоса",
                                value: Binding(
                                    get: { viewModel.subtalkerTopK > 0 ? viewModel.subtalkerTopK : 50 },
                                    set: { viewModel.subtalkerTopK = $0 }
                                ),
                                range: 1...200,
                                step: 1
                            )

                            parameterRow(
                                label: "Sub Top-P",
                                hint: "Top-P для эмбеддинга голоса",
                                value: Binding(
                                    get: { viewModel.subtalkerTopP > 0 ? viewModel.subtalkerTopP : 1.0 },
                                    set: { viewModel.subtalkerTopP = $0 }
                                ),
                                range: 0.1...1.0,
                                step: 0.05,
                                format: "%.2f"
                            )

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sub сэмплирование")
                                        .font(.callout)
                                    Text("Стохастика для эмбеддинга")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(width: labelWidth, alignment: .leading)
                                Toggle("", isOn: $viewModel.subtalkerDoSample)
                                    .labelsHidden()
                                Spacer()
                            }
                        }

                        // Сброс к умолчаниям
                        HStack {
                            Spacer()
                            Button("Сбросить к умолчаниям") {
                                viewModel.temperature = -1
                                viewModel.topK = -1
                                viewModel.topP = -1
                                viewModel.repetitionPenalty = -1
                                viewModel.doSample = true
                                viewModel.maxNewTokens = -1
                                viewModel.subtalkerTemperature = -1
                                viewModel.subtalkerTopK = -1
                                viewModel.subtalkerTopP = -1
                                viewModel.subtalkerDoSample = true
                            }
                            .font(.caption)
                            .buttonStyle(.link)
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.callout.weight(.medium))
            }

            // Progress
            if viewModel.isSynthesizing {
                VStack(spacing: 4) {
                    HStack {
                        Text("Озвучка сегмента \(viewModel.currentSegmentIndex + 1) из \(viewModel.totalSegments)\u{2026}")
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task {
            if viewModel.availableModels.isEmpty {
                await viewModel.loadModels()
            }
        }
    }

    // MARK: - Helpers

    /// Строка настройки с меткой, подсказкой, слайдером и значением
    @ViewBuilder
    private func parameterRow(
        label: String,
        hint: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.callout)
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: labelWidth, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: format, value.wrappedValue))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    /// Строка настройки для целочисленного параметра (Int)
    @ViewBuilder
    private func intParameterRow(
        label: String,
        hint: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.callout)
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: labelWidth, alignment: .leading)
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
            Text("\(value.wrappedValue)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

#Preview {
    VoiceoverStepView(
        viewModel: VoiceoverViewModel(
            project: VoiceoverProject(title: "Test"),
            ttsService: MockTTSService(),
            notificationService: MockNotificationService()
        )
    )
    .frame(width: 700, height: 500)
    .padding()
}
