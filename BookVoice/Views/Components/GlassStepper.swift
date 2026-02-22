//
//  GlassStepper.swift
//  BookVoice
//

import SwiftUI

struct GlassStepper: View {
    let steps: [String]
    let currentStep: Int
    var onStepTapped: ((Int) -> Void)?

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                    let stepNumber = index + 1
                    let isCompleted = stepNumber < currentStep
                    let isCurrent = stepNumber == currentStep
                    let isUpcoming = stepNumber > currentStep

                    HStack(spacing: 8) {
                        ZStack {
                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .glassEffect(.regular.tint(.accentColor), in: .circle)
                            } else if isCurrent {
                                Text("\(stepNumber)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                    .frame(width: 28, height: 28)
                                    .glassEffect(.regular.tint(.accentColor), in: .circle)
                            } else {
                                Text("\(stepNumber)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, height: 28)
                                    .glassEffect(.clear, in: .circle)
                            }
                        }

                        Text(title)
                            .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                            .foregroundStyle(isUpcoming ? .secondary : .primary)
                    }
                    .onTapGesture {
                        if isCompleted || isCurrent {
                            onStepTapped?(stepNumber)
                        }
                    }
                    .opacity(isUpcoming ? 0.6 : 1.0)

                    if stepNumber < steps.count {
                        Rectangle()
                            .fill(isCompleted ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassStepper(
            steps: ["Модель", "Текст", "Озвучка", "Тембр", "Экспорт"],
            currentStep: 3
        )
        GlassStepper(
            steps: ["Модель", "Текст", "Озвучка", "Тембр", "Экспорт"],
            currentStep: 1
        )
    }
    .padding(40)
}
