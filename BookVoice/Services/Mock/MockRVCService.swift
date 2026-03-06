//
//  MockRVCService.swift
//  BookVoice
//

import Foundation

nonisolated final class MockRVCService: RVCService, Sendable {
    func convert(
        inputURL: URL,
        outputURL: URL,
        modelPath: String,
        indexRate: Double,
        filterRadius: Int,
        protectVoiceless: Double
    ) async throws -> URL {
        try await Task.sleep(for: .milliseconds(800))

        // In mock mode, just copy input to output
        if FileManager.default.fileExists(atPath: inputURL.path) {
            try FileManager.default.copyItem(at: inputURL, to: outputURL)
        }
        return outputURL
    }

    func convertBatch(
        inputURLs: [URL],
        outputDirectory: URL,
        modelPath: String,
        indexRate: Double,
        filterRadius: Int,
        protectVoiceless: Double,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> [URL] {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        var results: [URL] = []
        for (i, inputURL) in inputURLs.enumerated() {
            let outputURL = outputDirectory.appendingPathComponent(
                "rvc_\(inputURL.deletingPathExtension().lastPathComponent).\(inputURL.pathExtension)"
            )
            let url = try await convert(
                inputURL: inputURL,
                outputURL: outputURL,
                modelPath: modelPath,
                indexRate: indexRate,
                filterRadius: filterRadius,
                protectVoiceless: protectVoiceless
            )
            results.append(url)
            progressHandler(Double(i + 1) / Double(inputURLs.count))
        }
        return results
    }

    func availableModels(at directory: URL) async throws -> [String] {
        try await Task.sleep(for: .milliseconds(200))
        return ["MockVoice_v1", "MockVoice_v2", "NaturalTone_v1"]
    }

    func cancel() async {}

    // MARK: - Training

    func startTraining(
        sampleAudioURL: URL,
        modelName: String,
        outputDirectory: URL,
        epochs: Int
    ) async throws -> String {
        "mock-job-\(UUID().uuidString.prefix(8))"
    }

    func trainingStatus(jobId: String) async throws -> RVCTrainingStatus {
        RVCTrainingStatus(
            jobId: jobId,
            phase: .completed,
            progress: 1.0,
            currentEpoch: 100,
            totalEpochs: 100,
            modelPath: "/mock/trained_model.pth",
            errorMessage: nil
        )
    }

    func cancelTraining(jobId: String) async throws {}
}
