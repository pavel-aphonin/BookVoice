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
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 16) {
        GlassButton(title: "Новая озвучка", icon: "plus.circle.fill") {}
        GlassButton(title: "Далее", icon: "chevron.right") {}
        GlassButton(title: "", icon: "gear") {}
    }
    .padding(40)
}
