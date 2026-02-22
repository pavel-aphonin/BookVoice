//
//  DropZone.swift
//  BookVoice
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZone: View {
    var allowedTypes: [UTType]
    var label: String
    var icon: String
    var isLoading: Bool
    var onDrop: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.05) : .clear)
                )

            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundColor(isTargeted ? .accentColor : .secondary)

                    Text(label)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("или нажмите для выбора")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        .onDrop(of: allowedTypes, isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .onTapGesture {
            browseFiles()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            for type in allowedTypes {
                if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                    provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
                        if let url = item as? URL {
                            DispatchQueue.main.async {
                                onDrop([url])
                            }
                        } else if let data = item as? Data,
                                  let url = URL(dataRepresentation: data, relativeTo: nil) {
                            DispatchQueue.main.async {
                                onDrop([url])
                            }
                        }
                    }
                    return true
                }
            }
        }
        return false
    }

    private func browseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = allowedTypes

        if panel.runModal() == .OK, let url = panel.url {
            onDrop([url])
        }
    }
}

#Preview {
    DropZone(
        allowedTypes: [.plainText],
        label: "Перетащите файл .txt или .epub сюда",
        icon: "doc.text",
        isLoading: false,
        onDrop: { _ in }
    )
    .frame(width: 400, height: 200)
    .padding(40)
}
