//
//  ModelSettingsStepView.swift
//  BookVoice
//

import SwiftUI

struct ModelSettingsStepView: View {
    @Bindable var viewModel: ModelSettingsViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Настройки модели")
                .font(.title2.bold())

            GlassPanel(padding: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    // Provider selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TTS-провайдер")
                            .font(.headline)
                        Picker("Provider", selection: $viewModel.selectedProvider) {
                            ForEach(TTSProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider()

                    // Connection settings
                    HStack(spacing: 16) {
                        GlassTextField(
                            label: "API URL",
                            text: $viewModel.apiURL,
                            prompt: "http://localhost"
                        )

                        GlassNumberField(
                            label: "Port",
                            value: $viewModel.apiPort,
                            range: 1...65535
                        )
                        .frame(width: 100)
                    }

                    Divider()

                    // System prompt
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Системный промпт")
                            .font(.headline)
                        Text("Пользовательские инструкции для модели обработки текста")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $viewModel.systemPrompt)
                            .font(.body)
                            .frame(minHeight: 100)
                            .padding(8)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Divider()

                    // Test connection
                    HStack {
                        GlassButton(
                            title: viewModel.isTestingConnection ? "Проверка..." : "Проверить подключение",
                            icon: "network"
                        ) {
                            Task { await viewModel.testConnection() }
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
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()
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
    .padding()
}
