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
                Text("Load Text")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                GlassDropZone(
                    allowedTypes: [.plainText, .epub],
                    label: "Drop .txt or .epub file here",
                    icon: "doc.text",
                    isLoading: viewModel.isLoading,
                    onDrop: { urls in
                        guard let url = urls.first else { return }
                        Task { await viewModel.loadFile(from: url) }
                    }
                )
                .frame(minHeight: 160)

                if let fileName = viewModel.fileName {
                    GlassPanel(padding: 12) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.tint)
                            Text(fileName)
                                .font(.headline)
                            Spacer()
                            Text("\(viewModel.characterCount) chars")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.wordCount) words")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                GlassPanel(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Segmentation")
                            .font(.headline)

                        Picker("Strategy", selection: $viewModel.strategy) {
                            ForEach(SegmentationStrategy.allCases, id: \.self) { strategy in
                                Text(strategy.displayName).tag(strategy)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.strategy) {
                            Task { await viewModel.segmentText() }
                        }

                        if viewModel.strategy == .fixedLength {
                            HStack {
                                Text("Words per segment:")
                                    .font(.subheadline)
                                TextField(
                                    "",
                                    value: $viewModel.fixedLength,
                                    format: .number
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .onChange(of: viewModel.fixedLength) {
                                    Task { await viewModel.segmentText() }
                                }
                            }
                        }

                        if viewModel.totalSegmentCount > 0 {
                            Label(
                                "\(viewModel.totalSegmentCount) segments",
                                systemImage: "text.line.first.and.arrowtriangle.forward"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
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
                Text("Preview")
                    .font(.title2.bold())

                if viewModel.rawText.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Text Loaded",
                        systemImage: "text.page",
                        description: Text("Drop a file to see a preview.")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(
                                Array(viewModel.previewSegments.enumerated()),
                                id: \.offset
                            ) { index, segment in
                                GlassPanel(padding: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Segment \(index + 1)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                        Text(segment)
                                            .font(.body)
                                            .lineLimit(6)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            if viewModel.totalSegmentCount > AppConstants.maxPreviewSegments {
                                Text("... and \(viewModel.totalSegmentCount - AppConstants.maxPreviewSegments) more segments")
                                    .foregroundStyle(.secondary)
                                    .italic()
                                    .padding(.top, 4)
                            }
                        }
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
