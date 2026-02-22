//
//  GlassSlider.swift
//  BookVoice
//

import SwiftUI

struct GlassSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var step: Double = 0.1
    var label: String = ""
    var format: String = "%.1f"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: format, value))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Slider(value: $value, in: range, step: step)
                .tint(.accentColor)
        }
    }
}

struct GlassIntSlider: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...10
    var label: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(value)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .tint(.accentColor)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassSlider(value: .constant(1.0), range: 0.5...2.0, label: "Speed")
        GlassSlider(value: .constant(0.75), range: 0...1, label: "Index Rate")
        GlassIntSlider(value: .constant(3), range: 0...7, label: "Filter Radius")
    }
    .frame(width: 300)
    .padding(40)
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
