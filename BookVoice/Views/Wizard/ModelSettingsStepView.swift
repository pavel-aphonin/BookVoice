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
                // TTS Provider
                VStack(alignment: .leading, spacing: 8) {
                    Text("TTS-провайдер")
                        .font(.headline)
                    Picker("Провайдер", selection: $viewModel.selectedProvider) {
                        ForEach(TTSProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Divider()

                // Connection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Подключение")
                        .font(.headline)
                    HStack(spacing: 12) {
                        TextField("API URL", text: $viewModel.apiURL, prompt: Text("http://localhost"))
                            .textFieldStyle(.plain)
                        TextField("Порт", value: $viewModel.apiPort, format: .number)
                            .textFieldStyle(.plain)
                            .frame(width: 80)
                    }
                }

                Divider()

                // System prompt
                VStack(alignment: .leading, spacing: 8) {
                    Text("Системный промпт")
                        .font(.headline)
                    TextEditor(text: $viewModel.systemPrompt)
                        .font(.body)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)

                    Text("Пользовательские инструкции для модели обработки текста")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Connection test
                HStack {
                    Button {
                        Task { await viewModel.testConnection() }
                    } label: {
                        Label(
                            viewModel.isTestingConnection ? "Проверка..." : "Проверить подключение",
                            systemImage: "network"
                        )
                    }
                    .disabled(viewModel.isTestingConnection || !viewModel.isValid)

                    if let result = viewModel.connectionTestResult {
                        Label(
                            result,
                            systemImage: viewModel.connectionTestSuccess
                                ? "checkmark.circle.fill"
                                : "xmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(viewModel.connectionTestSuccess ? .green : .red)
                        .lineLimit(2)
                    }
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
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
