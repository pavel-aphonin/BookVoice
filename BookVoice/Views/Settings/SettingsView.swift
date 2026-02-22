//
//  SettingsView.swift
//  BookVoice
//

import SwiftUI

struct SettingsView: View {
    @Environment(ServiceContainer.self) private var services

    var body: some View {
        TabView {
            Tab("Основные", systemImage: "gear") {
                GeneralSettingsView()
                    .environment(services)
            }

            Tab("API", systemImage: "key") {
                APISettingsView()
            }

            Tab("Модели", systemImage: "cpu") {
                ModelSettingsView()
                    .environment(services)
            }
        }
        .frame(width: 500, height: 400)
    }
}

#Preview {
    SettingsView()
        .environment(ServiceContainer.mock)
}
