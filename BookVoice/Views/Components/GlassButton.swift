//
//  GlassButton.swift
//  BookVoice
//

import SwiftUI

struct GlassButton: View {
    let title: String
    var icon: String?
    var role: ButtonRole?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                if !title.isEmpty {
                    Text(title)
                }
            }
            .font(.body.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: isHovering ? Color.accentGlow : .clear,
                        radius: 8
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius)
                    .stroke(
                        isHovering ? Color.accentColor.opacity(0.5) : Color.glassStroke,
                        lineWidth: isHovering ? 1 : AppConstants.glassStrokeWidth
                    )
            }
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        GlassButton(title: "New Voiceover", icon: "plus.circle.fill") {}
        GlassButton(title: "Next", icon: "chevron.right") {}
        GlassButton(title: "", icon: "gear") {}
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
