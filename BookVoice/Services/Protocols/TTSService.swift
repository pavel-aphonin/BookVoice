//
//  TTSService.swift
//  BookVoice
//

import Foundation

/// Extended generation options for TTS (primarily Qwen3 TTS).
struct TTSGenerationOptions: Sendable {
    var speaker: String = ""
    var language: String = ""
    var temperature: Double = -1     // -1 = use model default
    var topK: Int = -1               // -1 = use model default
    var topP: Double = -1            // -1 = use model default
    var repetitionPenalty: Double = -1  // -1 = use model default
    var doSample: Bool = true
    var maxNewTokens: Int = -1           // -1 = use model default (2048)
    // Voice cloning (Qwen Base models)
    var referenceAudioPath: String = ""   // Local path to reference WAV
    var referenceText: String = ""        // Transcript of reference audio
    var xVectorOnlyMode: Bool = false     // Faster but lower quality cloning
    // Subtalker parameters (voice cloning only — controls embedding generation)
    var subtalkerTemperature: Double = -1
    var subtalkerTopK: Int = -1
    var subtalkerTopP: Double = -1
    var subtalkerDoSample: Bool = true

    static let `default` = TTSGenerationOptions()
}

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
        outputURL: URL,
        options: TTSGenerationOptions
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
        options: TTSGenerationOptions,
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
