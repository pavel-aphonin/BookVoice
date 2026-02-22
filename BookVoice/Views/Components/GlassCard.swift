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
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
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
                Text("Моя книга")
                    .font(.headline)
                Text("15 янв. 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
    }
    .frame(width: 300)
    .padding(40)
}
