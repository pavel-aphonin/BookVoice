//
//  APISettingsView.swift
//  BookVoice
//

import SwiftUI

struct APISettingsView: View {
    @AppStorage("elevenLabsAPIKey") private var elevenLabsAPIKey = ""
    @AppStorage("customAPIEndpoint") private var customAPIEndpoint = ""
    @AppStorage("customAPIPort") private var customAPIPort = AppConstants.defaultAPIPort

    // LLM providers
    @AppStorage("openaiAPIKey") private var openaiAPIKey = ""
    @AppStorage("claudeAPIKey") private var claudeAPIKey = ""
    // Local LLM managed automatically by the app — no URL needed

    var body: some View {
        Form {
            // MARK: - LLM (Text Preprocessing)

            Section("OpenAI (подготовка текста)") {
                SecureField("API-ключ", text: $openaiAPIKey, prompt: Text("sk-..."))
                Text("Используется для LLM-разметки текста (ударения, паузы, интонация)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Claude / Anthropic (подготовка текста)") {
                SecureField("API-ключ", text: $claudeAPIKey, prompt: Text("sk-ant-..."))
                Text("Альтернативный LLM-провайдер для разметки текста")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - TTS

            Section("ElevenLabs") {
                SecureField("API-ключ", text: $elevenLabsAPIKey, prompt: Text("Введите API-ключ ElevenLabs"))
                Text("Получите API-ключ на elevenlabs.io")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Пользовательский TTS-сервер") {
                TextField("URL эндпоинта", text: $customAPIEndpoint, prompt: Text("http://localhost"))
                TextField(
                    "Порт",
                    value: $customAPIPort,
                    format: .number
                )
                .frame(width: 100)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    APISettingsView()
        .frame(width: 400, height: 300)
}
