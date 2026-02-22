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
                    GlassPanel(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Формат вывода")
                                .font(.headline)

                            Picker("Format", selection: $viewModel.outputFormat) {
                                ForEach(AudioFormat.allCases, id: \.self) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    GlassPanel(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Метаданные")
                                .font(.headline)

                            GlassTextField(
                                label: "Название",
                                text: $viewModel.metadataTitle,
                                prompt: "Название книги"
                            )

                            GlassTextField(
                                label: "Исполнитель / Чтец",
                                text: $viewModel.metadataArtist,
                                prompt: "Имя исполнителя"
                            )

                            HStack(spacing: 12) {
                                GlassTextField(
                                    label: "Альбом",
                                    text: $viewModel.metadataAlbum,
                                    prompt: "Название альбома"
                                )

                                GlassTextField(
                                    label: "Год",
                                    text: $viewModel.metadataYear,
                                    prompt: "2026"
                                )
                                .frame(width: 100)
                            }
                        }
                    }
                }

                // Right: Cover image and actions
                VStack(spacing: 16) {
                    GlassPanel(padding: 16) {
                        VStack(spacing: 12) {
                            Text("Обложка")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let data = viewModel.coverImageData,
                               let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.glassBackground)
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

                            GlassButton(title: "Выбрать изображение", icon: "photo.badge.plus") {
                                viewModel.selectCoverImage()
                            }
                        }
                    }

                    // Export status
                    if viewModel.isExporting {
                        GlassProgressBar(
                            progress: viewModel.progress,
                            label: "Экспорт..."
                        )
                    }

                    if let url = viewModel.outputURL {
                        GlassPanel(padding: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Экспорт завершён")
                                    .font(.subheadline)
                                Spacer()
                                GlassButton(title: "Показать в Finder", icon: "folder") {
                                    viewModel.revealInFinder()
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
