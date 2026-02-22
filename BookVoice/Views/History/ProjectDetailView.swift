//
//  ProjectDetailView.swift
//  BookVoice
//

import SwiftUI

struct ProjectDetailView: View {
    let project: VoiceoverProject

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    if let coverData = project.coverImageData,
                       let nsImage = NSImage(data: coverData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(project.title)
                            .font(.title.bold())

                        if !project.author.isEmpty {
                            Text(project.author)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        Label(project.status.displayName, systemImage: project.status.icon)
                            .foregroundStyle(project.status.color)

                        Text("Создан \(project.createdAt, style: .date)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                // Settings summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Настройки")
                        .font(.headline)
                    LabeledContent("Провайдер", value: project.ttsProvider.displayName)
                    LabeledContent("API", value: "\(project.apiURL):\(project.apiPort)")
                    LabeledContent("Сегментация", value: project.segmentationStrategy.displayName)
                    LabeledContent("Скорость", value: String(format: "%.1fx", project.ttsSpeed))
                    LabeledContent("Формат", value: project.outputFormat.displayName)
                    if project.rvcEnabled {
                        LabeledContent("RVC", value: "Включён")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Segments
                if !project.textSegments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Текстовые сегменты (\(project.textSegments.count))")
                            .font(.headline)
                        ForEach(project.textSegments.sorted(by: { $0.index < $1.index }).prefix(5), id: \.id) { segment in
                            HStack {
                                Text("Сегмент \(segment.index + 1)")
                                    .font(.caption.bold())
                                Text(String(segment.text.prefix(60)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        if project.textSegments.count > 5 {
                            Text("... и ещё \(project.textSegments.count - 5)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
        }
    }
}

#Preview {
    ProjectDetailView(project: VoiceoverProject(title: "My Book"))
        .frame(width: 500, height: 600)
}
