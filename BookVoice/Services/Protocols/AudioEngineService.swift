//
//  AudioEngineService.swift
//  BookVoice
//

import Foundation

protocol AudioEngineService: Sendable {
    /// Play an audio file
    func play(url: URL) async throws

    /// Pause playback
    func pause() async

    /// Stop playback
    func stop() async

    /// Current playback time in seconds
    var currentTime: Double { get async }

    /// Total duration of loaded audio in seconds
    var duration: Double { get async }

    /// Whether currently playing
    var isPlaying: Bool { get async }

    /// Concatenate multiple audio files into one
    func concatenate(
        files: [URL],
        outputURL: URL,
        format: AudioFormat,
        pauseBetweenSegments: TimeInterval,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL

    /// Write metadata to an audio file
    func writeMetadata(
        to url: URL,
        title: String?,
        artist: String?,
        album: String?,
        year: String?,
        coverImage: Data?
    ) async throws

    /// Get duration of an audio file without fully loading it
    func getDuration(of url: URL) async throws -> Double

    /// Generate waveform data (array of amplitude values)
    func generateWaveform(url: URL, samples: Int) async throws -> [Float]
}

enum AudioEngineError: LocalizedError {
    case fileNotFound(String)
    case playbackFailed(String)
    case concatenationFailed(String)
    case metadataWriteFailed(String)
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): "Audio file not found: \(path)"
        case .playbackFailed(let reason): "Playback failed: \(reason)"
        case .concatenationFailed(let reason): "Concatenation failed: \(reason)"
        case .metadataWriteFailed(let reason): "Metadata write failed: \(reason)"
        case .unsupportedFormat(let format): "Unsupported audio format: \(format)"
        }
    }
}
