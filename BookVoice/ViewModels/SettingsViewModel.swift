//
//  SettingsViewModel.swift
//  BookVoice
//

import Foundation
import AppKit

@Observable
final class SettingsViewModel {
    // General
    var defaultProvider: TTSProvider {
        get { TTSProvider(rawValue: UserDefaults.standard.string(forKey: "defaultProvider") ?? "silero") ?? .silero }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "defaultProvider") }
    }

    var defaultSegmentation: SegmentationStrategy {
        get { SegmentationStrategy(rawValue: UserDefaults.standard.string(forKey: "defaultSegmentation") ?? "byParagraph") ?? .byParagraph }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "defaultSegmentation") }
    }

    // API Keys
    var elevenLabsAPIKey: String {
        get { UserDefaults.standard.string(forKey: "elevenLabsAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "elevenLabsAPIKey") }
    }

    var customAPIEndpoint: String {
        get { UserDefaults.standard.string(forKey: "customAPIEndpoint") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "customAPIEndpoint") }
    }

    // Models
    var modelDirectoryPath: String {
        get { UserDefaults.standard.string(forKey: "modelDirectoryPath") ?? AppConstants.modelsDirectory.path }
        set { UserDefaults.standard.set(newValue, forKey: "modelDirectoryPath") }
    }

    var models: [ModelInfo] = []
    var isLoadingModels = false

    private let modelManager: any ModelManagerService

    init(modelManager: any ModelManagerService) {
        self.modelManager = modelManager
    }

    func loadModels() async {
        isLoadingModels = true
        do {
            let dir = URL(fileURLWithPath: modelDirectoryPath)
            models = try await modelManager.listModels(in: dir)
        } catch {
            models = []
        }
        isLoadingModels = false
    }

    func browseModelDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Выберите папку для хранения моделей"

        if panel.runModal() == .OK, let url = panel.url {
            modelDirectoryPath = url.path
            Task { await loadModels() }
        }
    }

    func openLogsFolder() {
        let url = AppConstants.logsDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
