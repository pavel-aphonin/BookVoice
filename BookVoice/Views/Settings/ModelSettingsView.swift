//
//  ModelSettingsView.swift
//  BookVoice
//

import SwiftUI

struct ModelSettingsView: View {
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Form {
            if let vm = viewModel {
                Section("Model Directory") {
                    HStack {
                        Text(vm.modelDirectoryPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Browse...") {
                            vm.browseModelDirectory()
                        }
                    }
                }

                Section("Installed Models") {
                    if vm.isLoadingModels {
                        ProgressView("Loading models...")
                    } else if vm.models.isEmpty {
                        Text("No models found in the selected directory.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.models, id: \.name) { model in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(model.name)
                                        .font(.body)
                                    Text(vm.formatFileSize(model.size))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(model.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Button("Refresh") {
                        Task { await vm.loadModels() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(modelManager: services.modelManager)
                Task { await viewModel?.loadModels() }
            }
        }
    }
}

#Preview {
    ModelSettingsView()
        .environment(ServiceContainer.mock)
        .frame(width: 400, height: 400)
}
