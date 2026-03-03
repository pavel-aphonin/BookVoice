//
//  MockTTSService.swift
//  BookVoice
//

import Foundation

nonisolated final class MockTTSService: TTSService, Sendable {
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
        options: TTSGenerationOptions = .default
    ) async throws -> URL {
        let wordCount = text.split(separator: " ").count
        let delayMs = min(Double(wordCount) * 20, 2000)
        try await Task.sleep(for: .milliseconds(Int(delayMs)))

        let durationSeconds = Double(wordCount) / (2.5 * speed)
        let wav = Self.generateSilentWav(durationSeconds: durationSeconds)
        try wav.write(to: outputURL)
        return outputURL
    }

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
        options: TTSGenerationOptions = .default,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> [URL] {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        var results: [URL] = []
        for (i, segment) in segments.enumerated() {
            let outputURL = outputDirectory.appendingPathComponent("segment_\(segment.index).wav")
            let url = try await synthesize(
                text: segment.text,
                modelName: modelName,
                provider: provider,
                speed: speed,
                pitch: pitch,
                emotion: emotion,
                apiURL: apiURL,
                apiPort: apiPort,
                outputURL: outputURL
            )
            results.append(url)
            progressHandler(Double(i + 1) / Double(segments.count))
        }
        return results
    }

    func availableModels(
        provider: TTSProvider,
        apiURL: String,
        apiPort: Int
    ) async throws -> [String] {
        try await Task.sleep(for: .milliseconds(300))
        switch provider {
        case .silero: return ["v3_en", "v3_de", "v3_fr", "v4_ru"]
        case .elevenLabs: return ["Rachel", "Domi", "Bella", "Antoni", "Elli"]
        case .kokoro: return ["kokoro-v1", "kokoro-v2"]
        case .qwenLocal: return ["0.6B-Base", "0.6B-CustomVoice", "1.7B-Base", "1.7B-CustomVoice", "1.7B-VoiceDesign"]
        case .qwenCloud: return ["qwen3-tts-flash"]
        case .custom: return ["default"]
        }
    }

    func cancel() async {}

    private static func generateSilentWav(durationSeconds: Double) -> Data {
        let sampleRate: UInt32 = 22050
        let numSamples = UInt32(durationSeconds * Double(sampleRate))
        let dataSize = numSamples * 2

        var data = Data()

        func appendUInt32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func appendUInt16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        appendUInt32(36 + dataSize)
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        appendUInt32(16)
        appendUInt16(1)              // PCM
        appendUInt16(1)              // mono
        appendUInt32(sampleRate)
        appendUInt32(sampleRate * 2) // byte rate
        appendUInt16(2)              // block align
        appendUInt16(16)             // bits per sample

        // data chunk
        data.append(contentsOf: "data".utf8)
        appendUInt32(dataSize)
        data.append(Data(count: Int(dataSize)))

        return data
    }
}
