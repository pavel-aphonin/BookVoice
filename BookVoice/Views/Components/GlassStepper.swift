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
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                let stepNumber = index + 1
                let isCompleted = stepNumber < currentStep
                let isCurrent = stepNumber == currentStep
                let isUpcoming = stepNumber > currentStep

                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                isCompleted ? Color.accentColor :
                                isCurrent ? Color.accentColor.opacity(0.3) :
                                Color.glassStroke
                            )
                            .frame(width: 28, height: 28)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(stepNumber)")
                                .font(.caption.bold())
                                .foregroundStyle(
                                    isCurrent ? .primary : .secondary
                                )
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
                        .fill(isCompleted ? Color.accentColor : Color.glassStroke)
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
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
            steps: ["Model", "Text", "Voice", "Timbre", "Export"],
            currentStep: 3
        )
        GlassStepper(
            steps: ["Model", "Text", "Voice", "Timbre", "Export"],
            currentStep: 1
        )
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
