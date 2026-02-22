//
//  ContentView.swift
//  BookVoice
//
//  Created by Павел Афонин on 22.02.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services
    @Query(sort: \VoiceoverProject.updatedAt, order: .reverse)
    private var allProjects: [VoiceoverProject]

    @State private var activeProject: VoiceoverProject?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var audioPlayer: AudioPlayerViewModel?
    @State private var searchText = ""
    @State private var projectToDelete: VoiceoverProject?
    @State private var showDeleteAlert = false

    private var filteredProjects: [VoiceoverProject] {
        allProjects.filter { project in
            searchText.isEmpty ||
            project.title.localizedCaseInsensitiveContains(searchText) ||
            project.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detail
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .containerBackground(.thickMaterial, for: .window)
        .background {
            WindowTitleHider()
                .allowsHitTesting(false)
        }
        .frame(
            minWidth: AppConstants.minWindowWidth,
            minHeight: AppConstants.minWindowHeight
        )
        .alert("Удалить проект?", isPresented: $showDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let project = projectToDelete {
                    if activeProject?.id == project.id {
                        withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
                            activeProject = nil
                            columnVisibility = .all
                        }
                    }
                    modelContext.delete(project)
                }
            }
        } message: {
            if let project = projectToDelete {
                Text("Вы уверены, что хотите удалить \"\(project.title)\"? Это действие нельзя отменить.")
            }
        }
        .onAppear {
            audioPlayer = AudioPlayerViewModel(audioEngine: services.audioEngine)
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        List {
            TextField("Поиск проектов...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.bottom, 4)

            Section("Недавние проекты") {
                ForEach(filteredProjects) { project in
                    SidebarProjectRow(project: project)
                        .contentShape(Rectangle())
                        .onTapGesture { openProject(project) }
                        .contextMenu {
                            Button("Открыть") { openProject(project) }
                            Divider()
                            Button("Удалить", role: .destructive) {
                                projectToDelete = project
                                showDeleteAlert = true
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if filteredProjects.isEmpty {
                if allProjects.isEmpty {
                    ContentUnavailableView(
                        "Нет проектов",
                        systemImage: "waveform",
                        description: Text("Создайте первую озвучку.")
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .navigationTitle("Проекты")
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        ZStack(alignment: .bottom) {
            if let project = activeProject {
                WizardContainerView(
                    project: project,
                    services: services,
                    onDismiss: { closeWizard() }
                )
                .id(project.id)
            } else {
                StartScreenView(onNewProject: { createNewProject() })
            }

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
    }

    // MARK: - Actions

    private func openProject(_ project: VoiceoverProject) {
        withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
            activeProject = project
            columnVisibility = .detailOnly
        }
    }

    private func closeWizard() {
        withAnimation(.easeInOut(duration: AppConstants.animationDuration)) {
            activeProject = nil
            columnVisibility = .all
        }
    }

    private func createNewProject() {
        let project = VoiceoverProject(title: "Новый проект")
        modelContext.insert(project)
        openProject(project)
    }
}

// MARK: - Sidebar Row

private struct SidebarProjectRow: View {
    let project: VoiceoverProject

    var body: some View {
        HStack(spacing: 10) {
            if let coverData = project.coverImageData,
               let nsImage = NSImage(data: coverData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "book.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(project.status.displayName, systemImage: project.status.icon)
                        .font(.caption2)
                        .foregroundStyle(project.status.color)

                    Text(project.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: VoiceoverProject.self, inMemory: true)
        .environment(ServiceContainer.mock)
}
