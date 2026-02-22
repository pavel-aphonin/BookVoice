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
                Section("Папка моделей") {
                    HStack {
                        Text(vm.modelDirectoryPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Обзор...") {
                            vm.browseModelDirectory()
                        }
                    }
                }

                Section("Установленные модели") {
                    if vm.isLoadingModels {
                        ProgressView("Загрузка моделей...")
                    } else if vm.models.isEmpty {
                        Text("Модели не найдены в выбранной папке.")
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

                    Button("Обновить") {
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
