//
//  StartScreenView.swift
//  BookVoice
//

import SwiftUI

struct StartScreenView: View {
    var onNewProject: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "book.and.wrench")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("BookVoice")
                .font(.largeTitle.bold())

            Text("Превратите книги в аудиокниги")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button {
                onNewProject()
            } label: {
                Label("Новая озвучка", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    StartScreenView(onNewProject: {})
        .frame(width: 600, height: 400)
}
