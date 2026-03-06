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

    // MARK: - Training

    /// Start training an RVC model from a voice sample. Returns a job ID for status polling.
    func startTraining(
        sampleAudioURL: URL,
        modelName: String,
        outputDirectory: URL,
        epochs: Int
    ) async throws -> String

    /// Poll training status by job ID.
    func trainingStatus(jobId: String) async throws -> RVCTrainingStatus

    /// Cancel an active training job.
    func cancelTraining(jobId: String) async throws
}

// MARK: - Training Status

struct RVCTrainingStatus: Sendable {
    enum Phase: String, Sendable {
        case preprocessing
        case extractingFeatures = "extracting"
        case training
        case completed
        case failed
        case cancelled
    }

    let jobId: String
    let phase: Phase
    let progress: Double
    let currentEpoch: Int?
    let totalEpochs: Int?
    let modelPath: String?
    let errorMessage: String?
}

// MARK: - Errors

enum RVCError: LocalizedError {
    case modelNotFound(String)
    case conversionFailed(String)
    case pythonExecutionFailed(String)
    case trainingFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path): "RVC model not found at: \(path)"
        case .conversionFailed(let reason): "Voice conversion failed: \(reason)"
        case .pythonExecutionFailed(let reason): "Python execution failed: \(reason)"
        case .trainingFailed(let reason): "Voice training failed: \(reason)"
        case .cancelled: "Conversion was cancelled"
        }
    }
}
