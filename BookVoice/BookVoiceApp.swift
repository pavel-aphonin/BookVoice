//
//  BookVoiceApp.swift
//  BookVoice
//
//  Created by Павел Афонин on 22.02.2026.
//

import SwiftUI
import SwiftData

@main
struct BookVoiceApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VoiceoverProject.self,
            TextSegment.self,
            AudioSegment.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(ServiceContainer.shared)
        }
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView()
                .environment(ServiceContainer.shared)
        }
        .modelContainer(sharedModelContainer)
    }
}
