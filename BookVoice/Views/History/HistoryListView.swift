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
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Text("All Projects")
                    .font(.title2.bold())

                Spacer()

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search projects...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                }
                .frame(maxWidth: 250)

                // Status filter
                Picker("Status", selection: $viewModel.selectedStatus) {
                    Text("All").tag(nil as ProjectStatus?)
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
                        "No Projects",
                        systemImage: "waveform",
                        description: Text("Create your first voiceover project.")
                    )
                } else {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { project in
                            GlassCard {
                                HistoryRowView(project: project)
                            }
                            .onTapGesture { onOpenProject(project) }
                            .contextMenu {
                                Button("Open") { onOpenProject(project) }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    projectToDelete = project
                                    showDeleteAlert = true
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(.ultraThinMaterial)
        .alert("Delete Project?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    modelContext.delete(project)
                }
            }
        } message: {
            if let project = projectToDelete {
                Text("Are you sure you want to delete \"\(project.title)\"?")
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
