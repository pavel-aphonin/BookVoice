//
//  TextUploadStepView.swift
//  BookVoice
//

import SwiftUI
import UniformTypeIdentifiers

struct TextUploadStepView: View {
    @Bindable var viewModel: TextUploadViewModel

    var body: some View {
        HSplitView {
            // Left: Drop zone and controls
            VStack(spacing: 16) {
                Text("Загрузка текста")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                DropZone(
                    allowedTypes: [.plainText, .epub],
                    label: "Перетащите файл .txt или .epub сюда",
                    icon: "doc.text",
                    isLoading: viewModel.isLoading,
                    onDrop: { urls in
                        guard let url = urls.first else { return }
                        Task { await viewModel.loadFile(from: url) }
                    }
                )
                .frame(minHeight: 160)

                if let fileName = viewModel.fileName {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.tint)
                        Text(fileName)
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.characterCount) символов")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(viewModel.wordCount) слов")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Сегментация")
                        .font(.headline)

                        Picker("Стратегия", selection: $viewModel.strategy) {
                            ForEach(SegmentationStrategy.allCases, id: \.self) { strategy in
                                Text(strategy.displayName).tag(strategy)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: viewModel.strategy) {
                            Task { await viewModel.segmentText() }
                        }

                        if viewModel.strategy == .fixedLength {
                            HStack {
                                Text("Слов в сегменте:")
                                    .font(.subheadline)
                                TextField(
                                    "",
                                    value: $viewModel.fixedLength,
                                    format: .number
                                )
                                .textFieldStyle(.plain)
                                .frame(width: 80)
                                .onChange(of: viewModel.fixedLength) {
                                    Task { await viewModel.segmentText() }
                                }
                            }
                        }

                        if viewModel.totalSegmentCount > 0 {
                            Label(
                                "\(viewModel.totalSegmentCount) сегментов",
                                systemImage: "text.line.first.and.arrowtriangle.forward"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Spacer()
            }
            .frame(minWidth: 300)
            .padding(.trailing, 8)

            // Right: Text preview
            VStack(alignment: .leading, spacing: 12) {
                Text("Предпросмотр")
                    .font(.title2.bold())

                if viewModel.rawText.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "Текст не загружен",
                        systemImage: "text.page",
                        description: Text("Перетащите файл для предпросмотра.")
                    )
                    Spacer()
                } else {
                    List(Array(viewModel.previewSegments.enumerated()), id: \.offset) { index, segment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Сегмент \(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(segment)
                                .font(.body)
                                .lineLimit(6)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)

                    if viewModel.totalSegmentCount > AppConstants.maxPreviewSegments {
                        Text("... и ещё \(viewModel.totalSegmentCount - AppConstants.maxPreviewSegments) сегментов")
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.top, 4)
                    }
                }
            }
            .frame(minWidth: 300)
            .padding(.leading, 8)
        }
    }
}

#Preview {
    TextUploadStepView(
        viewModel: TextUploadViewModel(
            project: VoiceoverProject(title: "Test"),
            textService: MockTextProcessingService()
        )
    )
    .frame(width: 800, height: 500)
    .padding()
}
