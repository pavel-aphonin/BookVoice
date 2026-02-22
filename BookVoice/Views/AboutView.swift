//
//  AboutView.swift
//  BookVoice
//

import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("BookVoice")
                .font(.title.bold())

            Text("Версия \(version) (\(build))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Создание аудиокниг с помощью TTS")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 300)
        .containerBackground(.thickMaterial, for: .window)
    }
}

struct AboutMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("О BookVoice") {
            openWindow(id: "about")
        }
    }
}

#Preview {
    AboutView()
}
