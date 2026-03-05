//
//  MockLLMService.swift
//  BookVoice
//

import Foundation

/// Mock LLM service for SwiftUI previews and tests.
nonisolated final class MockLLMService: LLMService, Sendable {
    func preprocessSegment(
        text: String,
        systemPrompt: String,
        provider: LLMProvider,
        model: String
    ) async throws -> String {
        try await Task.sleep(for: .milliseconds(300))
        // Простая мок-разметка: добавить тег и пару ударений
        return "[задумчиво] " + text
    }

    func preprocessBatch(
        segments: [String],
        systemPrompt: String,
        provider: LLMProvider,
        model: String,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> [String] {
        var results: [String] = []
        for (i, segment) in segments.enumerated() {
            guard !Task.isCancelled else { throw LLMError.cancelled }
            try await Task.sleep(for: .milliseconds(200))
            results.append("[задумчиво] " + segment)
            progressHandler(Double(i + 1) / Double(segments.count))
        }
        return results
    }

    func cancel() async {}

    func availableModels(provider: LLMProvider) async throws -> [String] {
        switch provider {
        case .openai:
            return ["gpt-4o-mini", "gpt-4o"]
        case .claude:
            return ["claude-sonnet-4-20250514", "claude-haiku-4-20250414"]
        case .local:
            return ["mock-model-3b.gguf", "mock-model-7b.gguf"]
        }
    }

    func checkConnection(provider: LLMProvider) async throws -> Bool {
        try await Task.sleep(for: .milliseconds(200))
        return true
    }

    func downloadModel(repoId: String, filename: String, expectedSizeBytes: Int) async throws {
        // Simulate download
        try await Task.sleep(for: .seconds(2))
    }

    func downloadProgress() async -> Double? {
        nil
    }
}
