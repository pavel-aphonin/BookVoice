//
//  ModelSettingsViewModel.swift
//  BookVoice
//

import Foundation

@Observable
final class ModelSettingsViewModel {
    var apiURL: String
    var apiPort: Int
    var selectedProvider: TTSProvider
    var systemPrompt: String

    var isTestingConnection = false
    var connectionTestResult: String?
    var connectionTestSuccess = false
    var errorMessage: String?

    var isValid: Bool {
        !apiURL.isEmpty && apiPort > 0 && apiPort <= 65535
    }

    private let ttsService: any TTSService

    init(project: VoiceoverProject, ttsService: any TTSService) {
        self.apiURL = project.apiURL
        self.apiPort = project.apiPort
        self.selectedProvider = project.ttsProvider
        self.systemPrompt = project.systemPrompt
        self.ttsService = ttsService
    }

    func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil
        errorMessage = nil

        do {
            let models = try await ttsService.availableModels(
                provider: selectedProvider,
                apiURL: apiURL,
                apiPort: apiPort
            )
            connectionTestResult = "Подключено. Найдено моделей: \(models.count) — \(models.joined(separator: ", "))"
            connectionTestSuccess = true
        } catch {
            connectionTestResult = "Ошибка подключения: \(error.localizedDescription)"
            connectionTestSuccess = false
        }

        isTestingConnection = false
    }

    func saveToProject(_ project: VoiceoverProject) {
        project.apiURL = apiURL
        project.apiPort = apiPort
        project.ttsProvider = selectedProvider
        project.systemPrompt = systemPrompt
        project.updatedAt = Date()
    }
}
