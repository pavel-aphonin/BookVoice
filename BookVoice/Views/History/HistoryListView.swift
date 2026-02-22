//
//  HistoryListView.swift
//  BookVoice
//

import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VoiceoverProject.updatedAt, order: .reverse)
    private var allProjects: [VoiceoverProject]

    @State private var viewModel = HistoryViewModel()
    @State private var projectToDelete: VoiceoverProject?
    @State private var showDeleteAlert = false

    var onBack: () -> Void
    var onOpenProject: (VoiceoverProject) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    onBack()
                } label: {
                    Label("Назад", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Text("Все проекты")
                    .font(.title2.bold())

                Spacer()

                // Search
                TextField("Поиск проектов...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 250)

                // Status filter
                Picker("Статус", selection: $viewModel.selectedStatus) {
                    Text("Все").tag(nil as ProjectStatus?)
                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status as ProjectStatus?)
                    }
                }
                .frame(width: 130)
            }
            .padding(16)

            Divider()

            // Project list
            let filtered = viewModel.filteredProjects(allProjects)

            if filtered.isEmpty {
                Spacer()
                if allProjects.isEmpty {
                    ContentUnavailableView(
                        "Нет проектов",
                        systemImage: "waveform",
                        description: Text("Создайте свой первый проект озвучки.")
                    )
                } else {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
                Spacer()
            } else {
                List(filtered) { project in
                    HistoryRowView(project: project)
                        .contentShape(Rectangle())
                        .onTapGesture { onOpenProject(project) }
                        .contextMenu {
                            Button("Открыть") { onOpenProject(project) }
                            Divider()
                            Button("Удалить", role: .destructive) {
                                projectToDelete = project
                                showDeleteAlert = true
                            }
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .alert("Удалить проект?", isPresented: $showDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let project = projectToDelete {
                    modelContext.delete(project)
                }
            }
        } message: {
            if let project = projectToDelete {
                Text("Вы уверены, что хотите удалить \"\(project.title)\"?")
            }
        }
    }
}

#Preview {
    HistoryListView(
        onBack: {},
        onOpenProject: { _ in }
    )
    .modelContainer(for: VoiceoverProject.self, inMemory: true)
    .frame(width: 800, height: 500)
}
