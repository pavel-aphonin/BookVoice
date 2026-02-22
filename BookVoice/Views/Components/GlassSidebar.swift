//
//  GlassSidebar.swift
//  BookVoice
//

import SwiftUI

struct GlassSidebarItem: Identifiable {
    let id: String
    let title: String
    let icon: String
}

struct GlassSidebar: View {
    let items: [GlassSidebarItem]
    @Binding var selectedId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                let isSelected = selectedId == item.id

                HStack(spacing: 8) {
                    Image(systemName: item.icon)
                        .frame(width: 20)
                        .foregroundColor(isSelected ? .accentColor : .secondary)

                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(isSelected ? .primary : .secondary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.15))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedId = item.id
                    }
                }
            }
        }
        .padding(8)
    }
}

#Preview {
    GlassSidebar(
        items: [
            GlassSidebarItem(id: "general", title: "Основные", icon: "gear"),
            GlassSidebarItem(id: "api", title: "API-ключи", icon: "key"),
            GlassSidebarItem(id: "models", title: "Модели", icon: "cpu"),
        ],
        selectedId: .constant("general")
    )
    .frame(width: 200, height: 200)
    .padding()
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
