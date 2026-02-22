//
//  GlassCard.swift
//  BookVoice
//

import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    @ViewBuilder var content: () -> Content

    @State private var isHovering = false

    init(
        cornerRadius: CGFloat = AppConstants.cardCornerRadius,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: isHovering ? Color.accentGlow.opacity(0.3) : .clear,
                        radius: 8
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isHovering ? Color.accentColor.opacity(0.3) : Color.glassStroke,
                        lineWidth: isHovering ? 1 : AppConstants.glassStrokeWidth
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
    }
}

#Preview {
    GlassCard {
        HStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.tertiary)
                .frame(width: 50, height: 50)
            VStack(alignment: .leading) {
                Text("My Book")
                    .font(.headline)
                Text("Jan 15, 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
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
