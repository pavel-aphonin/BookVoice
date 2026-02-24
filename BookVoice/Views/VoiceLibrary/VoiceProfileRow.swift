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
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "waveform.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !profile.descriptionText.isEmpty {
                        Text(profile.descriptionText)
                            .lineLimit(1)
                    } else {
                        Text("RVC-модель")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
