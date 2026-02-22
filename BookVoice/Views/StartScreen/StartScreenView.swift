//
//  StartScreenView.swift
//  BookVoice
//

import SwiftUI
import SwiftData

struct StartScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VoiceoverProject.updatedAt, order: .reverse)
    private var recentProjects: [VoiceoverProject]

    @State private var viewModel = StartScreenViewModel()

    var onNewProject: (VoiceoverProject) -> Void
    var onOpenProject: (VoiceoverProject) -> Void
    var onShowHistory: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Left: Hero action
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "book.and.wrench")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)

                Text("BookVoice")
                    .font(.largeTitle.bold())

                Text("Transform books into audiobooks")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                GlassButton(title: "New Voiceover", icon: "plus.circle.fill") {
                    let project = viewModel.createNewProject(in: modelContext)
                    onNewProject(project)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(40)

            Divider()

            // Right: Recent projects
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Recent Projects")
                        .font(.title2.bold())
                    Spacer()
                    if !recentProjects.isEmpty {
                        Button("See All") { onShowHistory() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                    }
                }

                if recentProjects.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Projects Yet",
                        systemImage: "waveform",
                        description: Text("Create your first voiceover to get started.")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(recentProjects.prefix(10)) { project in
                                GlassCard {
                                    ProjectRow(project: project)
                                }
                                .onTapGesture { onOpenProject(project) }
                                .contextMenu {
                                    Button("Open") { onOpenProject(project) }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        viewModel.confirmDelete(project)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .background(.ultraThinMaterial)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .alert("Delete Project?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteProject(in: modelContext)
            }
        } message: {
            if let project = viewModel.projectToDelete {
                Text("Are you sure you want to delete \"\(project.title)\"? This action cannot be undone.")
            }
        }
    }
}

private struct ProjectRow: View {
    let project: VoiceoverProject

    var body: some View {
        HStack(spacing: 12) {
            // Cover placeholder
            if let coverData = project.coverImageData,
               let nsImage = NSImage(data: coverData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.3), .accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "book.fill")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(project.status.displayName, systemImage: project.status.icon)
                        .font(.caption)
                        .foregroundStyle(project.status.color)

                    Text(project.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
    }
}

#Preview {
    StartScreenView(
        onNewProject: { _ in },
        onOpenProject: { _ in },
        onShowHistory: {}
    )
    .modelContainer(for: VoiceoverProject.self, inMemory: true)
    .environment(ServiceContainer.mock)
    .frame(width: 900, height: 600)
}
