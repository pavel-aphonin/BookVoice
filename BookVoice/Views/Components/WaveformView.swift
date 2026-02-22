//
//  WaveformView.swift
//  BookVoice
//

import SwiftUI

struct WaveformView: View {
    var samples: [Float]
    var progress: Double
    var accentColor: Color

    init(
        samples: [Float] = [],
        progress: Double = 0,
        accentColor: Color = .accentColor
    ) {
        self.samples = samples
        self.progress = progress
        self.accentColor = accentColor
    }

    var body: some View {
        GeometryReader { geometry in
            let displaySamples = samples.isEmpty ? generatePlaceholder() : samples
            let barWidth: CGFloat = max(2, geometry.size.width / CGFloat(displaySamples.count) - 1)
            let spacing: CGFloat = 1
            let midY = geometry.size.height / 2

            Canvas { context, size in
                for (index, sample) in displaySamples.enumerated() {
                    let x = CGFloat(index) * (barWidth + spacing)
                    let barHeight = CGFloat(sample) * size.height * 0.8
                    let rect = CGRect(
                        x: x,
                        y: midY - barHeight / 2,
                        width: barWidth,
                        height: max(barHeight, 1)
                    )

                    let progressPoint = progress * size.width
                    let color: Color = x < progressPoint ? accentColor : .secondary.opacity(0.4)

                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(color)
                    )
                }
            }
        }
    }

    private func generatePlaceholder() -> [Float] {
        (0..<50).map { _ in Float.random(in: 0.1...0.8) }
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformView(progress: 0.4)
            .frame(height: 60)

        WaveformView(
            samples: (0..<80).map { i in
                Float(sin(Double(i) * 0.2) * 0.4 + 0.5)
            },
            progress: 0.6
        )
        .frame(height: 40)
    }
    .padding(40)
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
