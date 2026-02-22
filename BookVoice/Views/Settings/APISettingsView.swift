//
//  APISettingsView.swift
//  BookVoice
//

import SwiftUI

struct APISettingsView: View {
    @AppStorage("elevenLabsAPIKey") private var elevenLabsAPIKey = ""
    @AppStorage("customAPIEndpoint") private var customAPIEndpoint = ""
    @AppStorage("customAPIPort") private var customAPIPort = AppConstants.defaultAPIPort

    var body: some View {
        Form {
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
    }
}

#Preview {
    APISettingsView()
        .frame(width: 400, height: 300)
}
