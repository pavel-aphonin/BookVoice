//
//  RVCService.swift
//  BookVoice
//

import Foundation

protocol RVCService: Sendable {
    /// Convert audio using an RVC model
    func convert(
        inputURL: URL,
        outputURL: URL,
        modelPath: String,
        indexRate: Double,
        filterRadius: Int,
        protectVoiceless: Double
    ) async throws -> URL

    /// Convert a batch of audio files
    func convertBatch(
        inputURLs: [URL],
        outputDirectory: URL,
        modelPath: String,
        indexRate: Double,
        filterRadius: Int,
        protectVoiceless: Double,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> [URL]

    /// List available RVC models at a directory
    func availableModels(at directory: URL) async throws -> [String]

    /// Cancel ongoing conversion
    func cancel() async
}

enum RVCError: LocalizedError {
    case modelNotFound(String)
    case conversionFailed(String)
    case pythonExecutionFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path): "RVC model not found at: \(path)"
        case .conversionFailed(let reason): "Voice conversion failed: \(reason)"
        case .pythonExecutionFailed(let reason): "Python execution failed: \(reason)"
        case .cancelled: "Conversion was cancelled"
        }
    }
}
