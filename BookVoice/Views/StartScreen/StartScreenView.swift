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

                Text("Превратите книги в аудиокниги")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button {
                    let project = viewModel.createNewProject(in: modelContext)
                    onNewProject(project)
                } label: {
                    Label("Новая озвучка", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(40)

            Divider()

            // Right: Recent projects
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Недавние проекты")
                        .font(.title2.bold())
                    Spacer()
                    if !recentProjects.isEmpty {
                        Button("Все проекты") { onShowHistory() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                    }
                }

                if recentProjects.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "Проектов пока нет",
                        systemImage: "waveform",
                        description: Text("Создайте первую озвучку, чтобы начать.")
                    )
                    Spacer()
                } else {
                    List(recentProjects.prefix(10), id: \.id) { project in
                        ProjectRow(project: project)
                            .contentShape(Rectangle())
                            .onTapGesture { onOpenProject(project) }
                            .contextMenu {
                                Button("Открыть") { onOpenProject(project) }
                                Divider()
                                Button("Удалить", role: .destructive) {
                                    viewModel.confirmDelete(project)
                                }
                            }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Настройки", systemImage: "gear")
                }
            }
        }
        .alert("Удалить проект?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                viewModel.deleteProject(in: modelContext)
            }
        } message: {
            if let project = viewModel.projectToDelete {
                Text("Вы уверены, что хотите удалить \"\(project.title)\"? Это действие нельзя отменить.")
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
                    .fill(.quaternary)
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
        .padding(.vertical, 4)
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
