//
//  LiveRVCService.swift
//  BookVoice
//
//  Sends audio to the local RVC Python server for voice conversion.
//

import Foundation

actor LiveRVCService: RVCService {

    private var isCancelled = false

    // MARK: - Convert

    func convert(
        inputURL: URL,
        outputURL: URL,
        modelPath: String,
        indexRate: Double,
        filterRadius: Int,
        protectVoiceless: Double
    ) async throws -> URL {
        guard !isCancelled else { throw RVCError.cancelled }

        let port = try await LocalServerManager.shared.ensureRVCServer()

        guard let url = URL(string: "http://127.0.0.1:\(port)/api/convert") else {
            throw RVCError.conversionFailed("Invalid RVC server URL")
        }

        // Read input audio file
        let audioData: Data
        do {
            audioData = try Data(contentsOf: inputURL)
        } catch {
            throw RVCError.conversionFailed("Cannot read input file: \(error.localizedDescription)")
        }

        // Build multipart/form-data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // RVC can be slow

        let fields: [(String, String)] = [
            ("model", modelPath),
            ("index_rate", String(indexRate)),
            ("filter_radius", String(filterRadius)),
            ("protect_voiceless", String(protectVoiceless)),
        ]

        request.httpBody = buildMultipartBody(
            boundary: boundary,
            audioData: audioData,
            audioFilename: inputURL.lastPathComponent,
            fields: fields
        )

        // Send request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw RVCError.conversionFailed("Network error: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RVCError.conversionFailed("Invalid response from RVC server")
        }

        if httpResponse.statusCode == 404 {
            let errorMsg = String(data: data, encoding: .utf8) ?? ""
            throw RVCError.modelNotFound(errorMsg)
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw RVCError.conversionFailed("RVC server error: \(errorMsg)")
        }

        try data.write(to: outputURL)
        return outputURL
    }

    // MARK: - Batch Convert

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

        isCancelled = false
        var results: [URL] = []

        for (i, inputURL) in inputURLs.enumerated() {
            guard !isCancelled, !Task.isCancelled else {
                throw RVCError.cancelled
            }

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

    // MARK: - Available Models

    func availableModels(at directory: URL) async throws -> [String] {
        // Try fetching from running RVC server first
        if await LocalServerManager.shared.isServerRunning(.rvc),
           let port = await LocalServerManager.shared.getPort(for: .rvc) {
            if let models = try? await fetchModelsFromServer(port: port) {
                return models
            }
        }

        // Fallback: scan the directory for model files
        return try scanModelsInDirectory(directory)
    }

    // MARK: - Cancel

    func cancel() async {
        isCancelled = true
    }

    // MARK: - Training

    func startTraining(
        sampleAudioURL: URL,
        modelName: String,
        outputDirectory: URL,
        epochs: Int
    ) async throws -> String {
        let port = try await LocalServerManager.shared.ensureRVCServer()

        guard let url = URL(string: "http://127.0.0.1:\(port)/api/train/start") else {
            throw RVCError.trainingFailed("Invalid RVC server URL")
        }

        let body: [String: Any] = [
            "sample_audio_path": sampleAudioURL.path,
            "model_name": modelName,
            "output_dir": outputDirectory.path,
            "epochs": epochs,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RVCError.trainingFailed("Failed to start training: \(errorMsg)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jobId = json["job_id"] as? String else {
            throw RVCError.trainingFailed("Invalid response from training endpoint")
        }

        return jobId
    }

    func trainingStatus(jobId: String) async throws -> RVCTrainingStatus {
        let port = try await LocalServerManager.shared.ensureRVCServer()

        guard let url = URL(string: "http://127.0.0.1:\(port)/api/train/status/\(jobId)") else {
            throw RVCError.trainingFailed("Invalid RVC server URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RVCError.trainingFailed("Failed to get training status: \(errorMsg)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statusStr = json["status"] as? String else {
            throw RVCError.trainingFailed("Invalid training status response")
        }

        let phase = RVCTrainingStatus.Phase(rawValue: statusStr) ?? .failed

        return RVCTrainingStatus(
            jobId: jobId,
            phase: phase,
            progress: json["progress"] as? Double ?? 0,
            currentEpoch: json["current_epoch"] as? Int,
            totalEpochs: json["total_epochs"] as? Int,
            modelPath: json["model_path"] as? String,
            errorMessage: json["error"] as? String
        )
    }

    func cancelTraining(jobId: String) async throws {
        let port = try await LocalServerManager.shared.ensureRVCServer()

        guard let url = URL(string: "http://127.0.0.1:\(port)/api/train/cancel/\(jobId)") else {
            throw RVCError.trainingFailed("Invalid RVC server URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw RVCError.trainingFailed("Failed to cancel training")
        }
    }

    // MARK: - Private

    private func fetchModelsFromServer(port: Int) async throws -> [String] {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/models") else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [String] else {
            return []
        }

        return models
    }

    private nonisolated func scanModelsInDirectory(_ directory: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        let modelExtensions: Set<String> = ["pth", "pt", "bin", "onnx"]

        return contents
            .filter { modelExtensions.contains($0.pathExtension.lowercased()) }
            .map { $0.lastPathComponent }
            .sorted()
    }
}

// MARK: - Multipart Helper

private func buildMultipartBody(
    boundary: String,
    audioData: Data,
    audioFilename: String,
    fields: [(String, String)]
) -> Data {
    var body = Data()

    func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            body.append(data)
        }
    }

    // Audio file field
    appendString("--\(boundary)\r\n")
    appendString("Content-Disposition: form-data; name=\"audio\"; filename=\"\(audioFilename)\"\r\n")
    appendString("Content-Type: audio/wav\r\n\r\n")
    body.append(audioData)
    appendString("\r\n")

    // Form fields
    for (name, value) in fields {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    appendString("--\(boundary)--\r\n")
    return body
}
