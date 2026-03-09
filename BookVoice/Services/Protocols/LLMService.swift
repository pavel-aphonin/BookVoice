//
//  LLMService.swift
//  BookVoice
//

import Foundation

/// Service for preprocessing text segments using LLM providers.
protocol LLMService: Sendable {
    /// Preprocess a single text segment using LLM to add stress marks, pauses, and expression tags.
    func preprocessSegment(
        text: String,
        systemPrompt: String,
        provider: LLMProvider,
        model: String
    ) async throws -> String

    /// Preprocess a batch of segments sequentially with progress reporting.
    func preprocessBatch(
        segments: [String],
        systemPrompt: String,
        provider: LLMProvider,
        model: String,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> [String]

    /// Cancel ongoing processing.
    func cancel() async

    /// Get list of available models for a provider.
    func availableModels(provider: LLMProvider) async throws -> [String]

    /// Check connection to a provider (API key validity or server health).
    func checkConnection(provider: LLMProvider) async throws -> Bool

    /// Download a model from HuggingFace (local provider only).
    func downloadModel(repoId: String, filename: String, expectedSizeBytes: Int) async throws

    /// Get current download progress (0.0–1.0), nil if no download is active.
    func downloadProgress() async -> Double?

    /// Delete a local model file.
    func deleteModel(filename: String) async throws

    /// Get list of installed models with file sizes.
    func installedModelsInfo() async throws -> [InstalledModelInfo]
}

/// Information about an installed local model.
struct InstalledModelInfo: Sendable {
    let filename: String
    let sizeGB: Double
    let isLoaded: Bool
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case apiKeyMissing(String)
    case connectionFailed(String)
    case processingFailed(String)
    case rateLimited(retryAfter: TimeInterval?)
    case invalidResponse(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing(let provider):
            "API-ключ для \(provider) не настроен. Укажите его в настройках."
        case .connectionFailed(let reason):
            "Ошибка подключения: \(reason)"
        case .processingFailed(let reason):
            "Ошибка обработки текста: \(reason)"
        case .rateLimited(let retry):
            if let retry {
                "Превышен лимит запросов. Повторите через \(Int(retry)) сек."
            } else {
                "Превышен лимит запросов. Попробуйте позже."
            }
        case .invalidResponse(let detail):
            "Неожиданный ответ от сервера: \(detail)"
        case .cancelled:
            "Обработка отменена"
        }
    }
}
