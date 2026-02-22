//
//  ModelSettingsStepView.swift
//  BookVoice
//

import SwiftUI

struct ModelSettingsStepView: View {
    @Bindable var viewModel: ModelSettingsViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Model Settings")
                .font(.title2.bold())

            GlassPanel(padding: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    // Provider selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TTS Provider")
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
                        Text("System Prompt")
                            .font(.headline)
                        Text("Custom instructions for the text processing model")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $viewModel.systemPrompt)
                            .font(.body)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.glassStroke, lineWidth: AppConstants.glassStrokeWidth)
                            }
                    }

                    Divider()

                    // Test connection
                    HStack {
                        GlassButton(
                            title: viewModel.isTestingConnection ? "Testing..." : "Test Connection",
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
