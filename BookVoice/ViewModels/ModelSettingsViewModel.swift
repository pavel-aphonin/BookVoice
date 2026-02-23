//
//  ModelSettingsViewModel.swift
//  BookVoice
//

import Foundation

@Observable
final class ModelSettingsViewModel {

    // MARK: - Default System Prompt

    static let defaultSystemPrompt = """
        Читай текст выразительно, как профессиональный диктор аудиокниг. \
        Делай естественные паузы на знаках препинания. \
        Имена собственные произноси чётко и разборчиво. \
        Прямую речь читай с интонацией персонажа. \
        Описания и авторский текст читай спокойным повествовательным тоном.
        """

    // MARK: - Common Properties

    var selectedProvider: TTSProvider
    var systemPrompt: String
    var errorMessage: String?

    // MARK: - Cloud / Custom API Properties

    var apiURL: String
    var apiPort: Int
    var apiKey: String  // For ElevenLabs

    var isTestingConnection = false
    var connectionTestResult: String?
    var connectionTestSuccess = false

    // MARK: - Local Setup Properties (Silero / Kokoro)

    var localSetupState: LocalSetupState = .notStarted
    var pythonStatus: ComponentStatus = .pending
    var dependenciesStatus: ComponentStatus = .pending
    var serverStatus: ComponentStatus = .pending
    var setupMessage: String?
    var isSettingUp = false

    // Generation counter to prevent stale async writes
    private var checkGeneration = 0

    // MARK: - Nested Types

    enum LocalSetupState: Equatable {
        case notStarted     // Haven't checked yet
        case checking       // Checking prerequisites
        case needsPython    // Python not found
        case needsInstall   // Dependencies or server need setup
        case installing     // Installation in progress
        case completed      // Everything ready
        case failed         // Something went wrong
    }

    enum ComponentStatus: Equatable {
        case pending        // ⚪ Not checked yet
        case checking       // 🔄 Currently checking
        case ready          // ✅ OK
        case notInstalled   // ⚪ Needs installation
        case installing     // 🔄 Being installed/started
        case failed(String) // ❌ Error

        static func == (lhs: ComponentStatus, rhs: ComponentStatus) -> Bool {
            switch (lhs, rhs) {
            case (.pending, .pending), (.checking, .checking), (.ready, .ready),
                 (.notInstalled, .notInstalled), (.installing, .installing):
                return true
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        switch selectedProvider {
        case .silero, .kokoro:
            return localSetupState == .completed
        case .elevenLabs:
            return connectionTestSuccess
        case .custom:
            return !apiURL.isEmpty && apiPort > 0 && apiPort <= 65535
        }
    }

    // MARK: - Private

    private let ttsService: any TTSService

    // MARK: - Init

    init(project: VoiceoverProject, ttsService: any TTSService) {
        self.selectedProvider = project.ttsProvider
        self.systemPrompt = project.systemPrompt
        self.apiURL = project.apiURL
        self.apiPort = project.apiPort
        self.apiKey = UserDefaults.standard.string(forKey: "elevenLabsAPIKey") ?? ""
        self.ttsService = ttsService
    }

    // MARK: - Provider Changed

    func onProviderChanged() {
        // Reset all states
        connectionTestResult = nil
        connectionTestSuccess = false
        errorMessage = nil
        localSetupState = .notStarted
        pythonStatus = .pending
        dependenciesStatus = .pending
        serverStatus = .pending
        setupMessage = nil
        isSettingUp = false
    }

    // MARK: - Local Setup: Check Prerequisites

    func checkLocalPrerequisites() async {
        guard selectedProvider.isLocal else { return }

        checkGeneration += 1
        let thisGeneration = checkGeneration

        localSetupState = .checking
        setupMessage = "Проверяю компоненты…"
        errorMessage = nil

        // Step 1: Check Python
        pythonStatus = .checking
        let hasPython = await LocalServerManager.shared.isPythonAvailable()
        guard thisGeneration == checkGeneration, !Task.isCancelled else { return }
        pythonStatus = hasPython ? .ready : .notInstalled

        guard hasPython else {
            dependenciesStatus = .pending
            serverStatus = .pending
            localSetupState = .needsPython
            setupMessage = "Для работы локальных моделей необходим Python 3"
            return
        }

        // Step 2: Check dependencies
        dependenciesStatus = .checking
        let providerName = selectedProvider == .silero ? "silero" : "kokoro"
        let hasDeps = await LocalServerManager.shared.areDependenciesInstalled(for: providerName)
        guard thisGeneration == checkGeneration, !Task.isCancelled else { return }
        dependenciesStatus = hasDeps ? .ready : .notInstalled

        guard hasDeps else {
            serverStatus = .pending
            localSetupState = .needsInstall
            setupMessage = nil
            return
        }

        // Step 3: Check server (auto-start if deps are ready)
        let isRunning = await LocalServerManager.shared.isServerRunning(.tts)
        guard thisGeneration == checkGeneration, !Task.isCancelled else { return }

        if isRunning {
            serverStatus = .ready
            localSetupState = .completed
            setupMessage = "Всё готово! Можно переходить к следующему шагу."
        } else {
            // Auto-start server since dependencies are already installed
            serverStatus = .installing
            setupMessage = "Запускаю сервер…"

            do {
                _ = try await LocalServerManager.shared.ensureTTSServer(provider: providerName)
                guard thisGeneration == checkGeneration, !Task.isCancelled else { return }
                serverStatus = .ready
                localSetupState = .completed
                setupMessage = "Всё готово! Можно переходить к следующему шагу."
            } catch {
                guard thisGeneration == checkGeneration, !Task.isCancelled else { return }
                serverStatus = .failed(friendlyError(error))
                localSetupState = .needsInstall
                setupMessage = "Не удалось запустить сервер"
                errorMessage = friendlyError(error)
            }
        }
    }

    // MARK: - Local Setup: Install

    func beginLocalSetup() async {
        guard !isSettingUp else { return }
        isSettingUp = true
        localSetupState = .installing
        errorMessage = nil

        let providerName = selectedProvider == .silero ? "silero" : "kokoro"

        // Step 1: Verify Python
        if pythonStatus != .ready {
            pythonStatus = .checking
            let hasPython = await LocalServerManager.shared.isPythonAvailable()
            if !hasPython {
                pythonStatus = .failed("Python 3 не найден")
                localSetupState = .needsPython
                setupMessage = "Установите Python 3 и попробуйте снова"
                isSettingUp = false
                return
            }
            pythonStatus = .ready
        }

        // Step 2: Install dependencies
        if dependenciesStatus != .ready {
            dependenciesStatus = .installing
            setupMessage = "Устанавливаю библиотеки для \(selectedProvider.displayName)…\nЭто может занять несколько минут. Не закрывайте приложение."

            do {
                try await LocalServerManager.shared.installDependencies(for: providerName)
                dependenciesStatus = .ready
            } catch {
                dependenciesStatus = .failed(friendlyError(error))
                localSetupState = .failed
                setupMessage = "Ошибка при установке библиотек"
                errorMessage = friendlyError(error)
                isSettingUp = false
                return
            }
        }

        // Step 3: Start server
        serverStatus = .installing
        setupMessage = "Запускаю сервер \(selectedProvider.displayName)…"

        do {
            _ = try await LocalServerManager.shared.ensureTTSServer(provider: providerName)
            serverStatus = .ready
            localSetupState = .completed
            setupMessage = "Всё готово! Можно переходить к следующему шагу."
        } catch {
            serverStatus = .failed(friendlyError(error))
            localSetupState = .failed
            setupMessage = "Не удалось запустить сервер"
            errorMessage = friendlyError(error)
        }

        isSettingUp = false
    }

    // MARK: - Cloud Connection Test

    func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil
        connectionTestSuccess = false
        errorMessage = nil

        // Save API key for ElevenLabs before testing
        if selectedProvider == .elevenLabs {
            UserDefaults.standard.set(apiKey, forKey: "elevenLabsAPIKey")
        }

        do {
            let models = try await ttsService.availableModels(
                provider: selectedProvider,
                apiURL: apiURL,
                apiPort: apiPort
            )
            let list = models.prefix(5).joined(separator: ", ")
            let extra = models.count > 5 ? " и ещё \(models.count - 5)" : ""
            connectionTestResult = "Подключено! Моделей: \(models.count) — \(list)\(extra)"
            connectionTestSuccess = true
        } catch {
            connectionTestResult = "Ошибка подключения: \(friendlyError(error))"
            connectionTestSuccess = false
        }

        isTestingConnection = false
    }

    // MARK: - System Prompt Helpers

    var hasDefaultPrompt: Bool {
        systemPrompt == Self.defaultSystemPrompt
    }

    func insertDefaultPrompt() {
        systemPrompt = Self.defaultSystemPrompt
    }

    // MARK: - Save

    func saveToProject(_ project: VoiceoverProject) {
        project.apiURL = apiURL
        project.apiPort = apiPort
        project.ttsProvider = selectedProvider
        project.systemPrompt = systemPrompt
        project.updatedAt = Date()

        if selectedProvider == .elevenLabs {
            UserDefaults.standard.set(apiKey, forKey: "elevenLabsAPIKey")
        }
    }

    // MARK: - Helpers

    private func friendlyError(_ error: Error) -> String {
        if let localErr = error as? LocalServerError {
            // Already has Russian descriptions
            return localErr.localizedDescription
        }
        if let ttsErr = error as? TTSError {
            switch ttsErr {
            case .connectionFailed(let reason):
                return "Ошибка подключения: \(reason)"
            case .modelNotFound(let name):
                return "Модель не найдена: \(name)"
            case .synthesisFaild(let reason):
                return "Ошибка синтеза: \(reason)"
            case .pythonExecutionFailed(let reason):
                return "Ошибка Python: \(reason)"
            case .cancelled:
                return "Операция отменена"
            }
        }
        return error.localizedDescription
    }
}
