//
//  VoiceProfileRow.swift
//  BookVoice
//

import SwiftUI

struct VoiceProfileRow: View {
    let profile: VoiceProfile

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: 36, height: 36)
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
        .padding(.vertical, 2)
        .help(statusTooltip)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch profile.trainingStatus {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        case .pending:
            Image(systemName: "clock.fill")
                .font(.callout)
                .foregroundStyle(.orange)
        case .training:
            ProgressView()
                .controlSize(.small)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.red)
        }
    }

    private var statusText: String {
        switch profile.trainingStatus {
        case .ready:
            profile.descriptionText.isEmpty ? "Готов к использованию" : profile.descriptionText
        case .pending:
            "Готовится к обучению\u{2026}"
        case .training:
            "Обучается\u{2026} \(Int((profile.trainingProgress ?? 0) * 100))%"
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

    private var statusTooltip: String {
        switch profile.trainingStatus {
        case .ready:
            "Голос готов. Выберите его на шаге \u{00AB}Тембр\u{00BB} в мастере озвучки."
        case .pending:
            "Голос скоро начнёт обучаться. Это произойдёт автоматически. Дождитесь, пока статус сменится на \u{00AB}Готов\u{00BB}."
        case .training:
            "Идёт обучение голоса. Это может занять 15\u{2013}20 минут. Вы получите уведомление, когда всё будет готово."
        case .failed:
            "Обучение не удалось. Попробуйте удалить этот голос и создать заново с другой записью."
        }
    }
}
