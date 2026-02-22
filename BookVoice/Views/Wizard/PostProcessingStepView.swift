//
//  PostProcessingStepView.swift
//  BookVoice
//

import SwiftUI

struct PostProcessingStepView: View {
    @Bindable var viewModel: PostProcessingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Обработка и экспорт")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: 24) {
                // Left: Format and metadata
                VStack(spacing: 16) {
                    GroupBox("Формат вывода") {
                        Picker("Формат", selection: $viewModel.outputFormat) {
                            ForEach(AudioFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    GroupBox("Метаданные") {
                        VStack(spacing: 10) {
                            TextField("Название", text: $viewModel.metadataTitle, prompt: Text("Название книги"))
                                .textFieldStyle(.roundedBorder)

                            TextField("Исполнитель / Чтец", text: $viewModel.metadataArtist, prompt: Text("Имя исполнителя"))
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 12) {
                                TextField("Альбом", text: $viewModel.metadataAlbum, prompt: Text("Название альбома"))
                                    .textFieldStyle(.roundedBorder)

                                TextField("Год", text: $viewModel.metadataYear, prompt: Text("2026"))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                        }
                    }
                }

                // Right: Cover image and actions
                VStack(spacing: 16) {
                    GroupBox("Обложка") {
                        VStack(spacing: 12) {
                            if let data = viewModel.coverImageData,
                               let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.quaternary)
                                    .frame(height: 160)
                                    .overlay {
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo")
                                                .font(.title)
                                                .foregroundStyle(.secondary)
                                            Text("Нет обложки")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                            }

                            Button {
                                viewModel.selectCoverImage()
                            } label: {
                                Label("Выбрать изображение", systemImage: "photo.badge.plus")
                            }
                        }
                    }

                    // Export status
                    if viewModel.isExporting {
                        VStack(spacing: 4) {
                            HStack {
                                Text("Экспорт...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(viewModel.progress * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: viewModel.progress)
                        }
                    }

                    if let _ = viewModel.outputURL {
                        GroupBox {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Экспорт завершён")
                                    .font(.subheadline)
                                Spacer()
                                Button {
                                    viewModel.revealInFinder()
                                } label: {
                                    Label("Показать в Finder", systemImage: "folder")
                                }
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }

            Spacer()
        }
    }
}

#Preview {
    PostProcessingStepView(
        viewModel: PostProcessingViewModel(
            project: VoiceoverProject(title: "My Book"),
            audioEngine: MockAudioEngineService()
        )
    )
    .frame(width: 800, height: 500)
    .padding()
}
