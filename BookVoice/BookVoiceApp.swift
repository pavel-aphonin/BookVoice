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
            VoiceProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(ServiceContainer.shared)
                .task {
                    await ServiceContainer.shared.notification.requestPermission()
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
            }
        }

        Settings {
            SettingsView()
                .environment(ServiceContainer.shared)
                .containerBackground(.thickMaterial, for: .window)
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.automatic)

        Window("О программе", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 280)
    }
}
