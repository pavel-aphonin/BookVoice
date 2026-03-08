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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Формат вывода")
                            .font(.headline)
                        Picker("Формат", selection: $viewModel.outputFormat) {
                            ForEach(AudioFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Пауза между фрагментами")
                            .font(.headline)
                        HStack(spacing: 8) {
                            Slider(value: $viewModel.segmentPauseDuration, in: 0...3.0, step: 0.1)
                            Text(String(format: "%.1f сек", viewModel.segmentPauseDuration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Метаданные")
                            .font(.headline)
                        VStack(spacing: 10) {
                            TextField("Название", text: $viewModel.metadataTitle, prompt: Text("Название книги"))
                                .textFieldStyle(.plain)

                            TextField("Исполнитель / Чтец", text: $viewModel.metadataArtist, prompt: Text("Имя исполнителя"))
                                .textFieldStyle(.plain)

                            HStack(spacing: 12) {
                                TextField("Альбом", text: $viewModel.metadataAlbum, prompt: Text("Название альбома"))
                                    .textFieldStyle(.plain)

                                TextField("Год", text: $viewModel.metadataYear, prompt: Text("2026"))
                                    .textFieldStyle(.plain)
                                    .frame(width: 100)
                            }
                        }
                    }
                }

                // Right: Cover image and actions
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Обложка")
                            .font(.headline)
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
                        .padding(12)
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
            audioEngine: MockAudioEngineService(),
            notificationService: MockNotificationService()
        )
    )
    .frame(width: 800, height: 500)
    .padding()
}
