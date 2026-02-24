//
//  VoiceProfileCreateSheet.swift
//  BookVoice
//

import SwiftUI
import SwiftData

struct VoiceProfileCreateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: VoiceLibraryViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Новый голосовой профиль")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Название")
                        .font(.headline)
                    TextField("Например: Диктор Анна", text: $viewModel.newName)
                        .textFieldStyle(.roundedBorder)
                }

                // Description
                VStack(alignment: .leading, spacing: 4) {
                    Text("Описание (необязательно)")
                        .font(.headline)
                    TextField("Краткое описание голоса", text: $viewModel.newDescription)
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                // Model file
                VStack(alignment: .leading, spacing: 4) {
                    Text("Файл модели RVC")
                        .font(.headline)
                    Text("Выберите обученный файл модели (.pth)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        if let url = viewModel.newModelURL {
                            Label(url.lastPathComponent, systemImage: "doc.fill")
                                .font(.subheadline)
                                .lineLimit(1)
                        } else {
                            Text("Файл не выбран")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            viewModel.importModel()
                        } label: {
                            Label("Выбрать", systemImage: "folder")
                        }
                    }
                }

                Divider()

                // Sample audio
                VStack(alignment: .leading, spacing: 4) {
                    Text("Образец голоса (необязательно)")
                        .font(.headline)
                    Text("Аудиозапись для предпрослушивания голоса")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        if let url = viewModel.newSampleAudioURL {
                            Label(url.lastPathComponent, systemImage: "waveform")
                                .font(.subheadline)
                                .lineLimit(1)
                        } else {
                            Text("Образец не выбран")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            viewModel.importSampleAudio()
                        } label: {
                            Label("Выбрать", systemImage: "waveform.badge.plus")
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Button("Отмена") {
                    viewModel.resetForm()
                    dismiss()
                }

                Spacer()

                Button("Создать") {
                    viewModel.createProfile(in: modelContext)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canCreate)
            }
        }
        .padding(24)
        .frame(width: 460, height: 480)
    }
}
