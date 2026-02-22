//
//  ModelSettingsStepView.swift
//  BookVoice
//

import SwiftUI

struct ModelSettingsStepView: View {
    @Bindable var viewModel: ModelSettingsViewModel

    var body: some View {
        Form {
            Section("TTS-провайдер") {
                Picker("Провайдер", selection: $viewModel.selectedProvider) {
                    ForEach(TTSProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("Подключение") {
                TextField("API URL", text: $viewModel.apiURL, prompt: Text("http://localhost"))
                TextField("Порт", value: $viewModel.apiPort, format: .number)
                    .frame(width: 100)
            }

            Section("Системный промпт") {
                TextEditor(text: $viewModel.systemPrompt)
                    .font(.body)
                    .frame(minHeight: 100)

                Text("Пользовательские инструкции для модели обработки текста")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
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
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
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
