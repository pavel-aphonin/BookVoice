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
    @Query(sort: \VoiceProfile.createdAt, order: .reverse)
    private var voiceProfiles: [VoiceProfile]

    @State private var activeProject: VoiceoverProject?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var audioPlayer: AudioPlayerViewModel?
    @State private var searchText = ""
    @State private var projectToDelete: VoiceoverProject?
    @State private var showDeleteAlert = false
    @State private var voiceLibraryVM = VoiceLibraryViewModel()
    @State private var isVoicesSectionExpanded = false
    @State private var isProjectsSectionExpanded = true
    @State private var renamingProject: VoiceoverProject?
    @State private var renamingVoice: VoiceProfile?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var showRenameVoiceAlert = false

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
        .sheet(isPresented: $voiceLibraryVM.showingCreateSheet) {
            VoiceProfileCreateSheet(viewModel: voiceLibraryVM)
        }
        .alert("Переименовать проект", isPresented: $showRenameAlert) {
            TextField("Название", text: $renameText)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить") {
                if let project = renamingProject, !renameText.isEmpty {
                    project.title = renameText
                    project.updatedAt = Date()
                }
            }
        }
        .alert("Переименовать голос", isPresented: $showRenameVoiceAlert) {
            TextField("Название", text: $renameText)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить") {
                if let voice = renamingVoice, !renameText.isEmpty {
                    voice.name = renameText
                }
            }
        }
        .alert("Удалить голосовой профиль?", isPresented: $voiceLibraryVM.showingDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let profile = voiceLibraryVM.profileToDelete {
                    voiceLibraryVM.deleteProfile(profile, from: modelContext)
                }
            }
        } message: {
            if let profile = voiceLibraryVM.profileToDelete {
                Text("Вы уверены, что хотите удалить голос \"\(profile.name)\"?")
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        List {
            TextField("Поиск...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.bottom, 4)

            // Projects section (expanded by default)
            Section {
                DisclosureGroup(isExpanded: $isProjectsSectionExpanded) {
                    if filteredProjects.isEmpty {
                        if allProjects.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 6) {
                                    Image(systemName: "book.closed")
                                        .font(.title2)
                                        .foregroundStyle(.quaternary)
                                    Text("Нет проектов")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 12)
                                Spacer()
                            }
                        } else {
                            Text("Ничего не найдено по запросу «\(searchText)»")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }
                    } else {
                        ForEach(filteredProjects) { project in
                            SidebarProjectRow(project: project)
                                .contentShape(Rectangle())
                                .onTapGesture { openProject(project) }
                                .contextMenu {
                                    Button("Открыть") { openProject(project) }
                                    Button("Переименовать") { startRenamingProject(project) }
                                    Divider()
                                    Button("Удалить", role: .destructive) {
                                        projectToDelete = project
                                        showDeleteAlert = true
                                    }
                                }
                        }
                    }
                } label: {
                    Label {
                        Text("Проекты")
                    } icon: {
                        Image(systemName: "book.fill")
                            .foregroundStyle(.blue)
                    }
                    .font(.subheadline.weight(.medium))
                }
            }

            // Voices section (collapsed by default)
            Section {
                DisclosureGroup(isExpanded: $isVoicesSectionExpanded) {
                    ForEach(voiceProfiles) { profile in
                        VoiceProfileRow(profile: profile)
                            .contextMenu {
                                Button("Переименовать") { startRenamingVoice(profile) }
                                Divider()
                                Button("Удалить", role: .destructive) {
                                    voiceLibraryVM.profileToDelete = profile
                                    voiceLibraryVM.showingDeleteAlert = true
                                }
                            }
                    }

                    Button {
                        voiceLibraryVM.resetForm()
                        voiceLibraryVM.showingCreateSheet = true
                    } label: {
                        Label("Добавить голос", systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                } label: {
                    Label {
                        Text("Голоса")
                    } icon: {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundStyle(.purple)
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("BookVoice")
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

    private func startRenamingProject(_ project: VoiceoverProject) {
        renamingProject = project
        renameText = project.title
        showRenameAlert = true
    }

    private func startRenamingVoice(_ voice: VoiceProfile) {
        renamingVoice = voice
        renameText = voice.name
        showRenameVoiceAlert = true
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
