//
//  TTSService.swift
//  BookVoice
//

import Foundation

protocol TTSService: Sendable {
    /// Synthesize a single text segment to an audio file
    func synthesize(
        text: String,
        modelName: String,
        provider: TTSProvider,
        speed: Double,
        pitch: Double,
        emotion: String?,
        apiURL: String,
        apiPort: Int,
        outputURL: URL
    ) async throws -> URL

    /// Synthesize a batch of segments with progress reporting
    func synthesizeBatch(
        segments: [(index: Int, text: String)],
        modelName: String,
        provider: TTSProvider,
        speed: Double,
        pitch: Double,
        emotion: String?,
        apiURL: String,
        apiPort: Int,
        outputDirectory: URL,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> [URL]

    /// List available voices/models for a provider
    func availableModels(
        provider: TTSProvider,
        apiURL: String,
        apiPort: Int
    ) async throws -> [String]

    /// Cancel ongoing synthesis
    func cancel() async
}

enum TTSError: LocalizedError {
    case modelNotFound(String)
    case synthesisFaild(String)
    case connectionFailed(String)
    case pythonExecutionFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name): "Model not found: \(name)"
        case .synthesisFaild(let reason): "Synthesis failed: \(reason)"
        case .connectionFailed(let reason): "Connection failed: \(reason)"
        case .pythonExecutionFailed(let reason): "Python execution failed: \(reason)"
        case .cancelled: "Synthesis was cancelled"
        }
    }
}
