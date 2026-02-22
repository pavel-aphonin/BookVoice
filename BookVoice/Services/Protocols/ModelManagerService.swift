//
//  ModelManagerService.swift
//  BookVoice
//

import Foundation

struct ModelInfo: Sendable {
    let name: String
    let size: Int64
    let date: Date
    let path: URL
}

protocol ModelManagerService: Sendable {
    /// Download a model from a URL
    func downloadModel(
        from url: URL,
        to destinationDirectory: URL,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL

    /// Validate that a model path exists and is the correct format
    func validateModelPath(_ path: String) async throws -> Bool

    /// List models in a directory
    func listModels(in directory: URL) async throws -> [ModelInfo]

    /// Delete a downloaded model
    func deleteModel(at path: URL) async throws

    /// Get the default model storage directory
    var defaultModelDirectory: URL { get }
}

enum ModelManagerError: LocalizedError {
    case downloadFailed(String)
    case invalidModelPath(String)
    case deleteFailed(String)
    case directoryNotFound(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason): "Model download failed: \(reason)"
        case .invalidModelPath(let path): "Invalid model path: \(path)"
        case .deleteFailed(let reason): "Failed to delete model: \(reason)"
        case .directoryNotFound(let path): "Directory not found: \(path)"
        }
    }
}
