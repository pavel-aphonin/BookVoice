//
//  MockAudioEngineService.swift
//  BookVoice
//

import Foundation

actor MockAudioEngineService: AudioEngineService {
    private var _isPlaying = false
    private var _currentTime: Double = 0
    private var _duration: Double = 0

    var currentTime: Double { _currentTime }
    var duration: Double { _duration }
    var isPlaying: Bool { _isPlaying }

    func play(url: URL) async throws {
        _duration = 60.0
        _currentTime = 0
        _isPlaying = true
    }

    func pause() async {
        _isPlaying = false
    }

    func stop() async {
        _isPlaying = false
        _currentTime = 0
    }

    func concatenate(
        files: [URL],
        outputURL: URL,
        format: AudioFormat,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        for (i, _) in files.enumerated() {
            try await Task.sleep(for: .milliseconds(200))
            progressHandler(Double(i + 1) / Double(files.count))
        }
        // Create an empty file as placeholder
        FileManager.default.createFile(atPath: outputURL.path, contents: Data())
        return outputURL
    }

    func writeMetadata(
        to url: URL,
        title: String?,
        artist: String?,
        album: String?,
        year: String?,
        coverImage: Data?
    ) async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    func getDuration(of url: URL) async throws -> Double {
        try await Task.sleep(for: .milliseconds(100))
        return 60.0
    }

    func generateWaveform(url: URL, samples: Int) async throws -> [Float] {
        try await Task.sleep(for: .milliseconds(200))
        return (0..<samples).map { i in
            Float(sin(Double(i) * 0.15) * 0.3 + 0.5)
        }
    }
}
