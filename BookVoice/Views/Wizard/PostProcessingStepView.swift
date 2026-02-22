//
//  PostProcessingStepView.swift
//  BookVoice
//

import SwiftUI

struct PostProcessingStepView: View {
    @Bindable var viewModel: PostProcessingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Post-Processing & Export")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: 24) {
                // Left: Format and metadata
                VStack(spacing: 16) {
                    GlassPanel(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Output Format")
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
                            Text("Metadata")
                                .font(.headline)

                            GlassTextField(
                                label: "Title",
                                text: $viewModel.metadataTitle,
                                prompt: "Book title"
                            )

                            GlassTextField(
                                label: "Artist / Narrator",
                                text: $viewModel.metadataArtist,
                                prompt: "Artist name"
                            )

                            HStack(spacing: 12) {
                                GlassTextField(
                                    label: "Album",
                                    text: $viewModel.metadataAlbum,
                                    prompt: "Album name"
                                )

                                GlassTextField(
                                    label: "Year",
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
                            Text("Cover Image")
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
                                            Text("No cover image")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                            }

                            GlassButton(title: "Select Image", icon: "photo.badge.plus") {
                                viewModel.selectCoverImage()
                            }
                        }
                    }

                    // Export status
                    if viewModel.isExporting {
                        GlassProgressBar(
                            progress: viewModel.progress,
                            label: "Exporting..."
                        )
                    }

                    if let url = viewModel.outputURL {
                        GlassPanel(padding: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Exported successfully")
                                    .font(.subheadline)
                                Spacer()
                                GlassButton(title: "Reveal in Finder", icon: "folder") {
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
