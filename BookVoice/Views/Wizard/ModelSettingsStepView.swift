//
//  ModelSettingsStepView.swift
//  BookVoice
//

import SwiftUI

struct ModelSettingsStepView: View {
    @Bindable var viewModel: ModelSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // TTS Provider picker
                providerSection

                // Provider-specific content
                switch viewModel.selectedProvider {
                case .silero, .kokoro:
                    localSetupSection
                case .elevenLabs:
                    elevenLabsSection
                case .custom:
                    customAPISection
                }

                // System prompt
                systemPromptSection

                // Error message
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            .padding(28)
        }
        .task(id: viewModel.selectedProvider) {
            viewModel.onProviderChanged()
            if viewModel.selectedProvider.isLocal {
                await viewModel.checkLocalPrerequisites()
            }
        }
    }

    // MARK: - Glass Container Modifier

    private func glassPanel<Content: View>(
        cornerRadius: CGFloat = 10,
        padding: CGFloat = 14,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
    }

    // MARK: - Provider Picker

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Модель озвучки")
                .font(.title3.weight(.semibold))

            Picker("Провайдер", selection: $viewModel.selectedProvider) {
                ForEach(TTSProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)

            Text(providerDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var providerDescription: String {
        switch viewModel.selectedProvider {
        case .silero:
            "Бесплатная локальная модель. Работает без интернета после установки."
        case .kokoro:
            "Локальная модель с высоким качеством речи. Работает без интернета после установки."
        case .elevenLabs:
            "Облачный сервис с реалистичными голосами. Требуется API-ключ и подключение к интернету."
        case .custom:
            "Подключение к стороннему серверу озвучки по HTTP API."
        }
    }

    // MARK: - Local Setup Section (Silero / Kokoro)

    private var localSetupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Настройка \(viewModel.selectedProvider.displayName)")
                .font(.title3.weight(.semibold))

            if viewModel.localSetupState != .notStarted {
                // Component status list in glass panel
                glassPanel(cornerRadius: 10, padding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        componentRow(
                            title: "Python 3",
                            helpText: "Python — язык программирования, на котором работают модели озвучки. Устанавливается один раз и не влияет на производительность вашего компьютера.",
                            status: viewModel.pythonStatus,
                            isLast: false
                        )
                        componentRow(
                            title: "Библиотеки для озвучки",
                            helpText: "Программные модули, которые позволяют модели преобразовывать текст в речь. Могут занимать 2\u{2013}5 ГБ на диске (включают нейросетевые модели).",
                            status: viewModel.dependenciesStatus,
                            isLast: false
                        )
                        componentRow(
                            title: "Сервер озвучки",
                            helpText: "Небольшая программа, которая запускается в фоне и обрабатывает запросы на озвучку. Работает только пока открыт BookVoice и автоматически завершается при закрытии.",
                            status: viewModel.serverStatus,
                            isLast: true
                        )
                    }
                    .padding(14)
                }
            }

            // Status message
            if let message = viewModel.setupMessage {
                HStack(alignment: .top, spacing: 8) {
                    if viewModel.isSettingUp
                        || viewModel.localSetupState == .checking
                    {
                        ProgressView()
                            .controlSize(.small)
                    } else if viewModel.localSetupState == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if viewModel.localSetupState == .failed
                        || viewModel.localSetupState == .needsPython
                    {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }

                    Text(message)
                        .font(.body)
                        .foregroundStyle(messageColor)
                }
            }

            // Action buttons
            localActionButtons

            if viewModel.localSetupState == .needsInstall
                || viewModel.localSetupState == .needsPython
            {
                Text(
                    "Первая настройка может занять несколько минут. Потребуется подключение к интернету."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var localActionButtons: some View {
        switch viewModel.localSetupState {
        case .needsPython:
            HStack(spacing: 12) {
                Link(destination: URL(string: "https://www.python.org/downloads/")!) {
                    Label("Скачать Python", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Проверить снова") {
                    Task { await viewModel.checkLocalPrerequisites() }
                }
                .controlSize(.large)
            }

        case .needsInstall:
            Button {
                Task { await viewModel.beginLocalSetup() }
            } label: {
                Label("Установить компоненты", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .failed:
            Button {
                Task { await viewModel.beginLocalSetup() }
            } label: {
                Label("Попробовать снова", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .completed:
            EmptyView()

        default:
            EmptyView()
        }
    }

    private var messageColor: Color {
        switch viewModel.localSetupState {
        case .completed: .green
        case .failed, .needsPython: .orange
        default: .secondary
        }
    }

    private func componentRow(
        title: String,
        helpText: String,
        status: ModelSettingsViewModel.ComponentStatus,
        isLast: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                statusIcon(for: status)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.body)

                helpButton(text: helpText)

                Spacer()

                Text(statusText(for: status))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            if !isLast {
                Divider()
                    .padding(.leading, 30)
            }
        }
    }

    private func helpButton(text: String) -> some View {
        // Use a button with popover since this is a simple help tip
        HelpTipButton(text: text)
    }

    @ViewBuilder
    private func statusIcon(
        for status: ModelSettingsViewModel.ComponentStatus
    ) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.quaternary)
        case .checking, .installing:
            ProgressView()
                .controlSize(.mini)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .notInstalled:
            Image(systemName: "circle.dashed")
                .foregroundStyle(.orange)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func statusText(
        for status: ModelSettingsViewModel.ComponentStatus
    ) -> String {
        switch status {
        case .pending: "Ожидает"
        case .checking: "Проверяю\u{2026}"
        case .ready: "Готово"
        case .notInstalled: "Не установлено"
        case .installing: "Устанавливается\u{2026}"
        case .failed(let msg): msg
        }
    }

    // MARK: - ElevenLabs Section

    private var elevenLabsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Подключение к ElevenLabs")
                .font(.title3.weight(.semibold))

            glassPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("API-ключ")
                        .font(.callout.weight(.medium))

                    SecureField(
                        "API-ключ",
                        text: $viewModel.apiKey,
                        prompt: Text("Вставьте ваш API-ключ ElevenLabs")
                    )
                    .textFieldStyle(.plain)
                    .font(.body)

                    Link(
                        "Получить ключ на elevenlabs.com \u{2192}",
                        destination: URL(string: "https://elevenlabs.io")!
                    )
                    .font(.callout)
                }
            }

            connectionTestRow
        }
    }

    // MARK: - Custom API Section

    private var customAPISection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Подключение к серверу")
                .font(.title3.weight(.semibold))

            glassPanel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("URL сервера")
                                .font(.callout.weight(.medium))
                            TextField(
                                "URL",
                                text: $viewModel.apiURL,
                                prompt: Text("http://localhost")
                            )
                            .textFieldStyle(.plain)
                            .font(.body)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Порт")
                                .font(.callout.weight(.medium))
                            TextField(
                                "Порт",
                                value: $viewModel.apiPort,
                                format: .number
                            )
                            .textFieldStyle(.plain)
                            .font(.body)
                            .frame(width: 80)
                        }
                    }

                    Text(
                        "Сервер должен поддерживать API: POST /api/tts, GET /api/models"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            connectionTestRow
        }
    }

    // MARK: - Connection Test Row

    private var connectionTestRow: some View {
        HStack {
            Button {
                Task { await viewModel.testConnection() }
            } label: {
                Label(
                    viewModel.isTestingConnection
                        ? "Проверяю\u{2026}" : "Проверить подключение",
                    systemImage: "network"
                )
            }
            .controlSize(.large)
            .disabled(viewModel.isTestingConnection || !isConnectionTestEnabled)

            if let result = viewModel.connectionTestResult {
                Label(
                    result,
                    systemImage: viewModel.connectionTestSuccess
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill"
                )
                .font(.callout)
                .foregroundStyle(
                    viewModel.connectionTestSuccess ? .green : .red
                )
                .lineLimit(2)
            }
        }
    }

    private var isConnectionTestEnabled: Bool {
        switch viewModel.selectedProvider {
        case .elevenLabs:
            return !viewModel.apiKey.isEmpty
        case .custom:
            return !viewModel.apiURL.isEmpty && viewModel.apiPort > 0
        default:
            return false
        }
    }

    // MARK: - System Prompt

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Системный промпт")
                .font(.title3.weight(.semibold))

            glassPanel(cornerRadius: 10, padding: 2) {
                TextEditor(text: $viewModel.systemPrompt)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
            }

            Text(
                "Пользовательские инструкции для обработки текста перед озвучкой"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Help Tip Button

private struct HelpTipButton: View {
    let text: String
    @State private var isShowingPopover = false

    var body: some View {
        Button {
            isShowingPopover.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover, arrowEdge: .trailing) {
            Text(text)
                .font(.callout)
                .padding(12)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ModelSettingsStepView(
        viewModel: ModelSettingsViewModel(
            project: VoiceoverProject(title: "Test"),
            ttsService: MockTTSService()
        )
    )
    .frame(width: 700, height: 500)
}
