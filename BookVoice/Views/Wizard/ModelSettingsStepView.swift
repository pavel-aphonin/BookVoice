//
//  ModelSettingsStepView.swift
//  BookVoice
//

import SwiftUI

struct ModelSettingsStepView: View {
    @Bindable var viewModel: ModelSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // TTS Provider picker
                providerSection

                Divider()

                // Provider-specific content
                switch viewModel.selectedProvider {
                case .silero, .kokoro:
                    localSetupSection
                case .elevenLabs:
                    elevenLabsSection
                case .custom:
                    customAPISection
                }

                Divider()

                // System prompt
                systemPromptSection

                // Error message
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding(24)
        }
        .task(id: viewModel.selectedProvider) {
            viewModel.onProviderChanged()
            if viewModel.selectedProvider.isLocal {
                await viewModel.checkLocalPrerequisites()
            }
        }
    }

    // MARK: - Provider Picker

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Модель озвучки")
                .font(.headline)

            Picker("Провайдер", selection: $viewModel.selectedProvider) {
                ForEach(TTSProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(providerDescription)
                .font(.caption)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Настройка \(viewModel.selectedProvider.displayName)")
                .font(.headline)

            if viewModel.localSetupState != .notStarted {
                // Component status list
                VStack(alignment: .leading, spacing: 0) {
                    componentRow(
                        title: "Python 3",
                        status: viewModel.pythonStatus,
                        isLast: false
                    )
                    componentRow(
                        title: "Библиотеки для озвучки",
                        status: viewModel.dependenciesStatus,
                        isLast: false
                    )
                    componentRow(
                        title: "Сервер озвучки",
                        status: viewModel.serverStatus,
                        isLast: true
                    )
                }
                .padding(12)
                .background(.fill.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        .font(.callout)
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
                .font(.caption)
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

                Button("Проверить снова") {
                    Task { await viewModel.checkLocalPrerequisites() }
                }
            }

        case .needsInstall:
            Button {
                Task { await viewModel.beginLocalSetup() }
            } label: {
                Label("Установить компоненты", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)

        case .failed:
            Button {
                Task { await viewModel.beginLocalSetup() }
            } label: {
                Label("Попробовать снова", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)

        case .completed:
            // Already shown via setupMessage
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
        status: ModelSettingsViewModel.ComponentStatus,
        isLast: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                statusIcon(for: status)
                    .frame(width: 18, height: 18)

                Text(title)
                    .font(.callout)

                Spacer()

                Text(statusText(for: status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)

            if !isLast {
                Divider()
                    .padding(.leading, 28)
            }
        }
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
        case .checking: "Проверяю…"
        case .ready: "Готово"
        case .notInstalled: "Не установлено"
        case .installing: "Устанавливается…"
        case .failed(let msg): msg
        }
    }

    // MARK: - ElevenLabs Section

    private var elevenLabsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Подключение к ElevenLabs")
                .font(.headline)

            SecureField(
                "API-ключ",
                text: $viewModel.apiKey,
                prompt: Text("Вставьте ваш API-ключ ElevenLabs")
            )
            .textFieldStyle(.plain)

            Link(
                "Получить ключ на elevenlabs.com →",
                destination: URL(string: "https://elevenlabs.io")!
            )
            .font(.caption)

            Divider()

            connectionTestRow
        }
    }

    // MARK: - Custom API Section

    private var customAPISection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Подключение к серверу")
                .font(.headline)

            HStack(spacing: 12) {
                TextField(
                    "URL сервера",
                    text: $viewModel.apiURL,
                    prompt: Text("http://localhost")
                )
                .textFieldStyle(.plain)

                TextField(
                    "Порт",
                    value: $viewModel.apiPort,
                    format: .number
                )
                .textFieldStyle(.plain)
                .frame(width: 80)
            }

            Text("Сервер должен поддерживать API: POST /api/tts, GET /api/models")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            connectionTestRow
        }
    }

    // MARK: - Connection Test Row (shared between ElevenLabs and Custom)

    private var connectionTestRow: some View {
        HStack {
            Button {
                Task { await viewModel.testConnection() }
            } label: {
                Label(
                    viewModel.isTestingConnection
                        ? "Проверяю…" : "Проверить подключение",
                    systemImage: "network"
                )
            }
            .disabled(viewModel.isTestingConnection || !isConnectionTestEnabled)

            if let result = viewModel.connectionTestResult {
                Label(
                    result,
                    systemImage: viewModel.connectionTestSuccess
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill"
                )
                .font(.caption)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Системный промпт")
                .font(.headline)
            TextEditor(text: $viewModel.systemPrompt)
                .font(.body)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)

            Text(
                "Пользовательские инструкции для обработки текста перед озвучкой"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
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
