//
//  TextPreprocessingStepView.swift
//  BookVoice
//

import SwiftUI

struct TextPreprocessingStepView: View {
    @Bindable var viewModel: TextPreprocessingViewModel

    var body: some View {
        HSplitView {
            // Left: Settings panel
            settingsPanel
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                .padding()

            // Right: Segment list & editor
            segmentPanel
                .frame(minWidth: 400, idealWidth: 500)
                .padding()
        }
    }

    // MARK: - Settings Panel (Left)

    @ViewBuilder
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Подготовка текста")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("LLM-модель расставит ударения, паузы и интонационные метки в тексте перед озвучкой.")
                .font(.callout)
                .foregroundStyle(.secondary)

            // Enable toggle
            Toggle("Использовать подготовку текста", isOn: $viewModel.isEnabled)
                .toggleStyle(.switch)

            if viewModel.isEnabled {
                Divider()

                llmConfigSection

                Divider()

                preprocessingOptionsSection

                Divider()

                processingControls

                Divider()

                promptSection
            }

            Spacer()
        }
        .onChange(of: viewModel.selectedProvider) {
            if viewModel.isEnabled {
                Task { await viewModel.checkConnectionAndLoadModels() }
            }
        }
        .onChange(of: viewModel.isEnabled) {
            if viewModel.isEnabled {
                Task { await viewModel.checkConnectionAndLoadModels() }
            }
        }
    }

    @ViewBuilder
    private var llmConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Провайдер LLM")
                .font(.headline)

            Picker("", selection: $viewModel.selectedProvider) {
                ForEach(LLMProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Connection status
            connectionStatusView

            // API key (for cloud providers)
            apiKeySection

            // Model picker
            modelPickerSection

            // Download section (for local provider with no models)
            modelDownloadSection
        }
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch viewModel.connectionStatus {
        case .unknown:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(viewModel.selectedProvider.isLocal ? "Запускаю LLM-сервер…" : "Проверяю подключение…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .connected:
            Label(
                viewModel.selectedProvider.isLocal ? "Сервер запущен" : "Подключено",
                systemImage: "checkmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(.green)
        case .failed(let msg):
            Label("Ошибка: \(msg)", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(3)
        }
    }

    @ViewBuilder
    private var apiKeySection: some View {
        if viewModel.selectedProvider.requiresAPIKey {
            let key = viewModel.selectedProvider.apiKeySettingsKey ?? ""
            APIKeyField(
                label: "API-ключ \(viewModel.selectedProvider.displayName)",
                settingsKey: key,
                placeholder: viewModel.selectedProvider == .openai ? "sk-..." : "sk-ant-..."
            )
        }
    }

    @ViewBuilder
    private var modelPickerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.isLoadingModels {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Загрузка моделей…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if !viewModel.availableModels.isEmpty {
                HStack {
                    Text("Модель")
                        .foregroundStyle(.secondary)
                    Picker("Модель", selection: $viewModel.selectedModel) {
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            } else if viewModel.connectionStatus == .connected && !viewModel.selectedProvider.isLocal {
                // Cloud provider connected but no models (shouldn't happen, but fallback)
                HStack {
                    Text("Модель")
                        .foregroundStyle(.secondary)
                    TextField("Название модели", text: $viewModel.selectedModel)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    @ViewBuilder
    private var modelDownloadSection: some View {
        if viewModel.selectedProvider.isLocal
            && viewModel.availableModels.isEmpty
            && !viewModel.isLoadingModels
            && viewModel.connectionStatus == .connected {
            VStack(alignment: .leading, spacing: 8) {
                Text("Скачайте модель для работы:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(TextPreprocessingViewModel.recommendedModels) { model in
                    Button {
                        Task { await viewModel.downloadModel(model) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model.displayName)
                                    .font(.callout)
                            }
                            Spacer()
                            Text("\(model.sizeGB, specifier: "%.1f") ГБ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isDownloading)
                }

                if viewModel.isDownloading {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: max(viewModel.downloadProgress, 0.01)) {
                            HStack {
                                Text("Загрузка модели…")
                                Spacer()
                                if viewModel.downloadProgress > 0 {
                                    Text("\(Int(viewModel.downloadedMB)) / \(Int(viewModel.downloadTotalMB)) МБ  (\(Int(viewModel.downloadProgress * 100))%)")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("подключение…")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preprocessing Options

    @ViewBuilder
    private var preprocessingOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Параметры разметки")
                    .font(.headline)
                Spacer()
                Text(viewModel.ttsProvider.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1), in: Capsule())
            }

            if viewModel.isUsingCustomPrompt {
                Label(
                    "Параметры не применяются при использовании своего промпта",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Group {
                Toggle("Ударения", isOn: $viewModel.preprocessingOptions.stressMarks)
                Toggle("Эмоции / интонация", isOn: $viewModel.preprocessingOptions.emotionMarkup)
                Toggle("Паузы", isOn: $viewModel.preprocessingOptions.pauseInsertion)
                Toggle("Числительные \u{2192} слова", isOn: $viewModel.preprocessingOptions.numberExpansion)
                Toggle("Раскрытие аббревиатур", isOn: $viewModel.preprocessingOptions.abbreviationExpansion)
                Toggle("Адаптация для аудио", isOn: $viewModel.preprocessingOptions.audioRephrasing)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(viewModel.isUsingCustomPrompt)

            HStack {
                Text("Интенсивность")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Picker("", selection: $viewModel.preprocessingOptions.intensity) {
                    ForEach(PreprocessingIntensity.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .disabled(viewModel.isUsingCustomPrompt)

            providerCapabilityNote
        }
    }

    @ViewBuilder
    private var providerCapabilityNote: some View {
        let note: String? = switch viewModel.ttsProvider {
        case .silero:
            "Silero не поддерживает теги. Разметка ограничена пунктуацией и ударениями."
        case .qwenLocal:
            "Qwen3 TTS поддерживает инструкции [happy], [sad] и др. на английском языке."
        case .qwenCloud:
            "Qwen3 Cloud: инструкции передаются через API. Текст будет чистым."
        case .kokoro:
            "Kokoro поддерживает теги <emotion> и <pause>."
        case .elevenLabs:
            "ElevenLabs хорошо работает с чистым текстом и пунктуацией."
        case .custom:
            nil
        }
        if let note {
            Label(note, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Processing Controls

    @ViewBuilder
    private var processingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isProcessing {
                ProgressView(value: viewModel.progress) {
                    HStack {
                        Text("Обработка сегментов…")
                        Spacer()
                        Text("\(viewModel.currentSegmentIndex + 1) из \(viewModel.totalSegments)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                Button("Остановить") {
                    Task { await viewModel.cancelProcessing() }
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button {
                    Task { await viewModel.processAll() }
                } label: {
                    Label("Обработать всё", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.originalSegments.isEmpty || viewModel.availableModels.isEmpty)

                if !viewModel.processedSegments.isEmpty {
                    Label("\(viewModel.processedSegments.count) сегментов обработано",
                          systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }
        }
    }

    @ViewBuilder
    private var promptSection: some View {
        DisclosureGroup("Системный промпт") {
            if viewModel.isUsingCustomPrompt {
                TextEditor(text: $viewModel.customPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.quaternary)
                    )

                Button("Вернуться к автоматическому промпту") {
                    viewModel.customPrompt = ""
                }
                .font(.caption)
            } else {
                ScrollView {
                    Text(viewModel.generatedPrompt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 80, maxHeight: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary)
                )

                Text("Промпт генерируется автоматически на основе провайдера и параметров")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Использовать свой промпт") {
                    viewModel.customPrompt = viewModel.generatedPrompt
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Segment Panel (Right)

    @ViewBuilder
    private var segmentPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.segmentStates.isEmpty {
                ContentUnavailableView(
                    "Нет сегментов",
                    systemImage: "text.alignleft",
                    description: Text("Загрузите текст на предыдущем шаге")
                )
            } else if !viewModel.isEnabled {
                ContentUnavailableView(
                    "Подготовка текста выключена",
                    systemImage: "forward.fill",
                    description: Text("Включите подготовку текста, чтобы добавить ударения, паузы и интонацию")
                )
            } else {
                segmentList
            }
        }
    }

    @ViewBuilder
    private var segmentList: some View {
        VSplitView {
            // Top: Segment list
            List(selection: $viewModel.selectedSegmentIndex) {
                ForEach(viewModel.segmentStates) { state in
                    SegmentRow(state: state)
                        .tag(state.index)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 150)

            // Bottom: Detail editor
            if let index = viewModel.selectedSegmentIndex,
               index < viewModel.segmentStates.count {
                segmentDetail(index: index)
                    .frame(minHeight: 200)
            }
        }
    }

    @ViewBuilder
    private func segmentDetail(index: Int) -> some View {
        let state = viewModel.segmentStates[index]

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Сегмент \(index + 1)")
                    .font(.headline)
                Spacer()

                if state.status == .completed || state.status == .failed {
                    Button {
                        Task { await viewModel.reprocessSegment(index) }
                    } label: {
                        Label("Переобработать", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isProcessing)
                }
            }

            // Original text
            GroupBox("Оригинал") {
                ScrollView {
                    Text(state.originalText)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 100)
            }

            // Processed text (editable)
            GroupBox("Разметка") {
                if let processed = state.processedText {
                    let binding = Binding(
                        get: { processed },
                        set: { viewModel.updateProcessedSegment(index, text: $0) }
                    )
                    TextEditor(text: binding)
                        .font(.system(.body, design: .serif))
                        .frame(minHeight: 80)
                } else {
                    Text("Ещё не обработан")
                        .foregroundStyle(.tertiary)
                        .italic()
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Segment Row

private struct SegmentRow: View {
    let state: PreprocessingSegmentState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: state.statusIcon)
                .foregroundStyle(state.statusColor)
                .imageScale(.small)

            Text("#\(state.index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.previewOriginal)
                    .lineLimit(1)
                    .font(.callout)

                if let preview = state.previewProcessed {
                    Text(preview)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - API Key Field (inline)

private struct APIKeyField: View {
    let label: String
    let settingsKey: String
    let placeholder: String

    @AppStorage private var apiKey: String

    init(label: String, settingsKey: String, placeholder: String) {
        self.label = label
        self.settingsKey = settingsKey
        self.placeholder = placeholder
        self._apiKey = AppStorage(wrappedValue: "", settingsKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SecureField(label, text: $apiKey, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)

            if apiKey.isEmpty {
                Label("Ключ не задан", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let vm = TextPreprocessingViewModel(
        project: VoiceoverProject(title: "Test"),
        llmService: MockLLMService()
    )
    vm.prepareSegments([
        "Он подошёл к замку и вставил ключ в замок.",
        "Дорогие друзья, мы собрались здесь не случайно.",
        "Она посмотрела на него с удивлением и отвернулась.",
    ])
    return TextPreprocessingStepView(viewModel: vm)
        .frame(width: 900, height: 600)
}
