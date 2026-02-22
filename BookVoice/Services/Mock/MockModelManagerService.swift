//
//  MockModelManagerService.swift
//  BookVoice
//

import Foundation

nonisolated final class MockModelManagerService: ModelManagerService, Sendable {
    var defaultModelDirectory: URL {
        AppConstants.modelsDirectory
    }

    func downloadModel(
        from url: URL,
        to destinationDirectory: URL,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        for i in 1...10 {
            try await Task.sleep(for: .milliseconds(300))
            progressHandler(Double(i) / 10.0)
        }
        let destination = destinationDirectory.appendingPathComponent(url.lastPathComponent)
        FileManager.default.createFile(atPath: destination.path, contents: Data())
        return destination
    }

    func validateModelPath(_ path: String) async throws -> Bool {
        try await Task.sleep(for: .milliseconds(100))
        return !path.isEmpty
    }

    func listModels(in directory: URL) async throws -> [ModelInfo] {
        try await Task.sleep(for: .milliseconds(200))
        return [
            ModelInfo(
                name: "silero_v4_ru.pt",
                size: 52_000_000,
                date: Date().addingTimeInterval(-86400 * 7),
                path: directory.appendingPathComponent("silero_v4_ru.pt")
            ),
            ModelInfo(
                name: "rvc_natural_v1.pth",
                size: 120_000_000,
                date: Date().addingTimeInterval(-86400 * 3),
                path: directory.appendingPathComponent("rvc_natural_v1.pth")
            ),
            ModelInfo(
                name: "kokoro_v2.bin",
                size: 85_000_000,
                date: Date().addingTimeInterval(-86400),
                path: directory.appendingPathComponent("kokoro_v2.bin")
            ),
        ]
    }

    func deleteModel(at path: URL) async throws {
        try await Task.sleep(for: .milliseconds(100))
    }
}
