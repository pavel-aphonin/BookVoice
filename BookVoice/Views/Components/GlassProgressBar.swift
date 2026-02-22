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

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(max(progress, 0), 1))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.glassStroke, lineWidth: AppConstants.glassStrokeWidth)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassProgressBar(progress: 0.65, label: "Synthesizing segment 7 of 10...")
        GlassProgressBar(progress: 0.3, label: "Converting...")
        GlassProgressBar(progress: 1.0, label: "Complete")
    }
    .frame(width: 400)
    .padding(40)
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
