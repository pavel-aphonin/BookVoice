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
                SecureField("API Key", text: $elevenLabsAPIKey, prompt: Text("Enter your ElevenLabs API key"))
                Text("Get your API key from elevenlabs.io")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Custom TTS Server") {
                TextField("Endpoint URL", text: $customAPIEndpoint, prompt: Text("http://localhost"))
                TextField(
                    "Port",
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
