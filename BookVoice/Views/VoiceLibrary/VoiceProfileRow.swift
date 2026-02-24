//
//  VoiceProfileRow.swift
//  BookVoice
//

import SwiftUI

struct VoiceProfileRow: View {
    let profile: VoiceProfile

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 28, height: 28)
                .overlay {
                    statusIcon
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch profile.trainingStatus {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .pending:
            Image(systemName: "clock.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .training:
            ProgressView()
                .controlSize(.mini)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }

    private var statusText: String {
        switch profile.trainingStatus {
        case .ready:
            profile.descriptionText.isEmpty ? "Готов" : profile.descriptionText
        case .pending:
            "Ожидает обучения"
        case .training:
            "Обучается\u{2026}"
        case .failed:
            "Ошибка обучения"
        }
    }

    private var statusColor: Color {
        switch profile.trainingStatus {
        case .ready: .gray
        case .pending: .orange
        case .training: .gray
        case .failed: .red
        }
    }
}
