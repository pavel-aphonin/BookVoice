//
//  HistoryRowView.swift
//  BookVoice
//

import SwiftUI

struct HistoryRowView: View {
    let project: VoiceoverProject

    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let coverData = project.coverImageData,
               let nsImage = NSImage(data: coverData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "book.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                    .lineLimit(1)

                if !project.author.isEmpty {
                    Text(project.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label(project.status.displayName, systemImage: project.status.icon)
                        .font(.caption)
                        .foregroundStyle(project.status.color)

                    Text(project.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Шаг \(project.currentStep)/5")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                if project.ttsProvider != .silero {
                    Text(project.ttsProvider.displayName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let project = VoiceoverProject(title: "War and Peace")
    let _ = {
        project.author = "Leo Tolstoy"
        project.status = .synthesizing
        project.currentStep = 3
    }()

    List {
        HistoryRowView(project: project)
    }
    .listStyle(.inset(alternatesRowBackgrounds: true))
    .frame(width: 400)
    .padding()
}
