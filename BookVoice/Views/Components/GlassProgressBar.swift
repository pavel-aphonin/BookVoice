//
//  GlassProgressBar.swift
//  BookVoice
//

import SwiftUI

struct GlassProgressBar: View {
    var progress: Double
    var label: String = ""
    var showPercentage: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty || showPercentage {
                HStack {
                    if !label.isEmpty {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if showPercentage {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ProgressView(value: min(max(progress, 0), 1))
                .tint(.accentColor)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassProgressBar(progress: 0.65, label: "Синтез сегмента 7 из 10...")
        GlassProgressBar(progress: 0.3, label: "Конвертация...")
        GlassProgressBar(progress: 1.0, label: "Завершено")
    }
    .frame(width: 400)
    .padding(40)
}
