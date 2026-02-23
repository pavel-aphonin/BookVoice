//
//  LiveAudioEngineService.swift
//  BookVoice
//

import Foundation
@preconcurrency import AVFoundation

actor LiveAudioEngineService: AudioEngineService {

    private var player: AVAudioPlayer?
    private var _isPlaying = false

    // MARK: - Playback

    var currentTime: Double {
        player?.currentTime ?? 0
    }

    var duration: Double {
        player?.duration ?? 0
    }

    var isPlaying: Bool {
        _isPlaying
    }

    func play(url: URL) async throws {
        player?.stop()

        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            throw AudioEngineError.playbackFailed(error.localizedDescription)
        }

        guard let player else {
            throw AudioEngineError.playbackFailed("Failed to create audio player")
        }

        player.prepareToPlay()

        guard player.play() else {
            throw AudioEngineError.playbackFailed("AVAudioPlayer.play() returned false")
        }

        _isPlaying = true
    }

    func pause() async {
        player?.pause()
        _isPlaying = false
    }

    func stop() async {
        player?.stop()
        player?.currentTime = 0
        _isPlaying = false
    }

    // MARK: - Concatenation

    func concatenate(
        files: [URL],
        outputURL: URL,
        format: AudioFormat,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        guard !files.isEmpty else {
            throw AudioEngineError.concatenationFailed("No input files provided")
        }

        // Read the first file to determine the processing format
        let firstFile: AVAudioFile
        do {
            firstFile = try AVAudioFile(forReading: files[0])
        } catch {
            throw AudioEngineError.concatenationFailed("Cannot read first audio file: \(error.localizedDescription)")
        }

        let processingFormat = firstFile.processingFormat
        let sampleRate = processingFormat.sampleRate
        let channelCount = processingFormat.channelCount

        // Calculate total frame count for all files
        var totalFrames: AVAudioFrameCount = 0
        var audioFiles: [AVAudioFile] = [firstFile]

        for i in 1..<files.count {
            do {
                let file = try AVAudioFile(forReading: files[i])
                audioFiles.append(file)
            } catch {
                throw AudioEngineError.concatenationFailed("Cannot read audio file \(files[i].lastPathComponent): \(error.localizedDescription)")
            }
        }

        for file in audioFiles {
            totalFrames += AVAudioFrameCount(file.length)
        }

        // Determine output format and write
        switch format {
        case .wav:
            try concatenateToWAV(audioFiles: audioFiles, outputURL: outputURL, format: processingFormat, progressHandler: progressHandler)

        case .m4a:
            try concatenateToM4A(audioFiles: audioFiles, outputURL: outputURL, sampleRate: sampleRate, channelCount: channelCount, progressHandler: progressHandler)

        case .mp3:
            // Write to temp WAV first, then convert with afconvert
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")
            defer { try? FileManager.default.removeItem(at: tempURL) }

            try concatenateToWAV(audioFiles: audioFiles, outputURL: tempURL, format: processingFormat) { progress in
                progressHandler(progress * 0.8) // 80% for concatenation
            }

            // Try converting to MP3 with lame, fall back to M4A
            let mp3Success = tryConvertToMP3(input: tempURL, output: outputURL)
            if !mp3Success {
                try concatenateToM4A(audioFiles: audioFiles, outputURL: outputURL, sampleRate: sampleRate, channelCount: channelCount) { progress in
                    progressHandler(0.8 + progress * 0.2)
                }
            }
            progressHandler(1.0)

        case .flac:
            // Write WAV first, then convert with afconvert to FLAC
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")
            defer { try? FileManager.default.removeItem(at: tempURL) }

            try concatenateToWAV(audioFiles: audioFiles, outputURL: tempURL, format: processingFormat) { progress in
                progressHandler(progress * 0.8)
            }

            try convertWithAfconvert(input: tempURL, output: outputURL, formatArgs: ["-d", "flac", "-f", "flac"])
            progressHandler(1.0)
        }

        return outputURL
    }

    // MARK: - Metadata

    func writeMetadata(
        to url: URL,
        title: String?,
        artist: String?,
        album: String?,
        year: String?,
        coverImage: Data?
    ) async throws {
        let ext = url.pathExtension.lowercased()

        guard ext == "m4a" || ext == "mp4" || ext == "m4b" else {
            // Metadata writing only supported for M4A/M4B
            return
        }

        let asset = AVURLAsset(url: url)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw AudioEngineError.metadataWriteFailed("Cannot create export session")
        }

        var metadataItems: [AVMutableMetadataItem] = []

        if let title, !title.isEmpty {
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyTitle as NSString
            item.value = title as NSString
            metadataItems.append(item)
        }

        if let artist, !artist.isEmpty {
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyArtist as NSString
            item.value = artist as NSString
            metadataItems.append(item)
        }

        if let album, !album.isEmpty {
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyAlbumName as NSString
            item.value = album as NSString
            metadataItems.append(item)
        }

        if let year, !year.isEmpty {
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyCreationDate as NSString
            item.value = year as NSString
            metadataItems.append(item)
        }

        if let coverImage, !coverImage.isEmpty {
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyArtwork as NSString
            item.value = coverImage as NSData
            metadataItems.append(item)
        }

        guard !metadataItems.isEmpty else { return }

        // Export to temp file then replace original
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)

        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        exportSession.metadata = metadataItems

        do {
            try await exportSession.export(to: tempURL, as: .m4a)
        } catch {
            throw AudioEngineError.metadataWriteFailed(error.localizedDescription)
        }

        // Replace original file with the one containing metadata
        do {
            try FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: tempURL, to: url)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw AudioEngineError.metadataWriteFailed("Failed to replace file: \(error.localizedDescription)")
        }
    }

    // MARK: - Duration

    func getDuration(of url: URL) async throws -> Double {
        // Try AVAudioFile first (faster for WAV/CAF)
        if let audioFile = try? AVAudioFile(forReading: url) {
            let frames = Double(audioFile.length)
            let sampleRate = audioFile.fileFormat.sampleRate
            if sampleRate > 0 {
                return frames / sampleRate
            }
        }

        // Fallback to AVURLAsset (works for all formats)
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    // MARK: - Waveform

    func generateWaveform(url: URL, samples: Int) async throws -> [Float] {
        guard samples > 0 else { return [] }

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw AudioEngineError.fileNotFound(error.localizedDescription)
        }

        let frameCount = AVAudioFrameCount(audioFile.length)
        guard frameCount > 0 else { return Array(repeating: 0, count: samples) }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
            throw AudioEngineError.playbackFailed("Cannot create audio buffer")
        }

        do {
            try audioFile.read(into: buffer)
        } catch {
            throw AudioEngineError.playbackFailed("Cannot read audio data: \(error.localizedDescription)")
        }

        guard let channelData = buffer.floatChannelData?[0] else {
            return Array(repeating: 0, count: samples)
        }

        let totalFrames = Int(buffer.frameLength)
        let samplesPerBucket = max(1, totalFrames / samples)
        var waveform: [Float] = []

        for i in 0..<samples {
            let start = i * samplesPerBucket
            let end = min(start + samplesPerBucket, totalFrames)
            guard start < totalFrames else {
                waveform.append(0)
                continue
            }

            // Compute RMS amplitude for this bucket
            var sumSquares: Float = 0
            for j in start..<end {
                let sample = channelData[j]
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(end - start))
            waveform.append(rms)
        }

        // Normalize to 0...1
        let maxVal = waveform.max() ?? 1
        if maxVal > 0 {
            waveform = waveform.map { $0 / maxVal }
        }

        return waveform
    }

    // MARK: - Private: Concatenation Helpers

    private func concatenateToWAV(
        audioFiles: [AVAudioFile],
        outputURL: URL,
        format: AVAudioFormat,
        progressHandler: @Sendable (Double) -> Void
    ) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        } catch {
            throw AudioEngineError.concatenationFailed("Cannot create output file: \(error.localizedDescription)")
        }

        for (i, inputFile) in audioFiles.enumerated() {
            let frameCount = AVAudioFrameCount(inputFile.length)
            guard frameCount > 0 else { continue }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFile.processingFormat, frameCapacity: frameCount) else {
                continue
            }

            do {
                try inputFile.read(into: buffer)

                // Convert format if needed
                if inputFile.processingFormat != format {
                    guard let converter = AVAudioConverter(from: inputFile.processingFormat, to: format),
                          let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                        throw AudioEngineError.concatenationFailed("Cannot convert audio format for file \(i)")
                    }

                    var error: NSError?
                    let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                        outStatus.pointee = .haveData
                        return buffer
                    }
                    if status == .error {
                        throw AudioEngineError.concatenationFailed("Format conversion failed: \(error?.localizedDescription ?? "unknown")")
                    }
                    try outputFile.write(from: convertedBuffer)
                } else {
                    try outputFile.write(from: buffer)
                }
            } catch let e as AudioEngineError {
                throw e
            } catch {
                throw AudioEngineError.concatenationFailed("Failed to process file \(i): \(error.localizedDescription)")
            }

            progressHandler(Double(i + 1) / Double(audioFiles.count))
        }
    }

    private func concatenateToM4A(
        audioFiles: [AVAudioFile],
        outputURL: URL,
        sampleRate: Double,
        channelCount: AVAudioChannelCount,
        progressHandler: @Sendable (Double) -> Void
    ) throws {
        // First concatenate to temporary WAV
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        guard let format = audioFiles.first?.processingFormat else {
            throw AudioEngineError.concatenationFailed("No audio format available")
        }

        try concatenateToWAV(audioFiles: audioFiles, outputURL: tempURL, format: format) { progress in
            progressHandler(progress * 0.7)
        }

        // Convert WAV to M4A using afconvert
        try convertWithAfconvert(
            input: tempURL,
            output: outputURL,
            formatArgs: ["-d", "aac", "-f", "m4af", "-b", "192000"]
        )
        progressHandler(1.0)
    }

    private func convertWithAfconvert(input: URL, output: URL, formatArgs: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [input.path] + formatArgs + [output.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw AudioEngineError.concatenationFailed("afconvert failed to start: \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AudioEngineError.concatenationFailed("afconvert failed: \(errorMsg)")
        }
    }

    private nonisolated func tryConvertToMP3(input: URL, output: URL) -> Bool {
        // Try using lame if available
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["lame", "--preset", "standard", input.path, output.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
