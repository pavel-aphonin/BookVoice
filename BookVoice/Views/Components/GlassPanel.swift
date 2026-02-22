//
//  GlassPanel.swift
//  BookVoice
//

import SwiftUI

struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat
    var padding: CGFloat
    @ViewBuilder var content: () -> Content

    init(
        cornerRadius: CGFloat = AppConstants.glassCornerRadius,
        padding: CGFloat = 0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    GlassPanel(padding: 20) {
        VStack {
            Text("Glass Panel")
                .font(.title)
            Text("С эффектом Liquid Glass")
                .foregroundStyle(.secondary)
        }
    }
    .frame(width: 300, height: 200)
    .padding()
}
