//
//  ContentView.swift
//  BookVoice
//
//  Created by Павел Афонин on 22.02.2026.
//

import SwiftUI
import SwiftData

enum AppScreen: Equatable {
    case start
    case wizard(VoiceoverProject)
    case history

    static func == (lhs: AppScreen, rhs: AppScreen) -> Bool {
        switch (lhs, rhs) {
        case (.start, .start): true
        case (.history, .history): true
        case (.wizard(let a), .wizard(let b)): a.id == b.id
        default: false
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services
    @State private var currentScreen: AppScreen = .start
    @State private var audioPlayer: AudioPlayerViewModel?

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch currentScreen {
                case .start:
                    StartScreenView(
                        onNewProject: { project in
                            withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
                                currentScreen = .wizard(project)
                            }
                        },
                        onOpenProject: { project in
                            withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
                                currentScreen = .wizard(project)
                            }
                        },
                        onShowHistory: {
                            withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
                                currentScreen = .history
                            }
                        }
                    )

                case .wizard(let project):
                    WizardContainerView(
                        project: project,
                        services: services,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
                                currentScreen = .start
                            }
                        }
                    )

                case .history:
                    HistoryListView(
                        onBack: {
                            withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
                                currentScreen = .start
                            }
                        },
                        onOpenProject: { project in
                            withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
                                currentScreen = .wizard(project)
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Audio player bar
            if let player = audioPlayer, player.isVisible {
                AudioPlayerBar(
                    title: player.currentTitle,
                    isPlaying: player.isPlaying,
                    currentTime: player.currentTime,
                    duration: player.duration,
                    onPlayPause: { Task { await player.togglePlayPause() } },
                    onStop: { Task { await player.stop() } },
                    onSeek: { player.seek(to: $0) }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .frame(
            minWidth: AppConstants.minWindowWidth,
            minHeight: AppConstants.minWindowHeight
        )
        .onAppear {
            audioPlayer = AudioPlayerViewModel(audioEngine: services.audioEngine)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: VoiceoverProject.self, inMemory: true)
        .environment(ServiceContainer.mock)
}
