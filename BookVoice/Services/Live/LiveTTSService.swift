//
//  LiveTTSService.swift
//  BookVoice
//
//  Routes TTS requests to ElevenLabs cloud API or local Python server (Silero/Kokoro).
//

import Foundation

actor LiveTTSService: TTSService {

    private static let requestTimeout: TimeInterval = 30
    /// Qwen models need extra time: first request downloads & loads model (3-5 min)
    private static let qwenFirstRequestTimeout: TimeInterval = 600  // 10 min
    private var isCancelled = false

    // MARK: - Synthesize

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
        guard !isCancelled else { throw TTSError.cancelled }

        switch provider {
        case .elevenLabs:
            return try await synthesizeElevenLabs(
                text: text,
                voiceId: modelName,
                speed: speed,
                outputURL: outputURL
            )

        case .silero, .kokoro, .qwenLocal:
            return try await synthesizeLocal(
                text: text,
                modelName: modelName,
                provider: provider,
                speed: speed,
                pitch: pitch,
                emotion: emotion,
                outputURL: outputURL,
                options: options
            )

        case .qwenCloud:
            return try await synthesizeQwenCloud(
                text: text,
                modelName: modelName,
                speed: speed,
                emotion: emotion,
                outputURL: outputURL
            )

        case .custom:
            return try await synthesizeCustomAPI(
                text: text,
                modelName: modelName,
                speed: speed,
                pitch: pitch,
                emotion: emotion,
                apiURL: apiURL,
                apiPort: apiPort,
                outputURL: outputURL
            )
        }
    }

    // MARK: - Batch Synthesis

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

        isCancelled = false
        var results: [URL] = []

        for (i, segment) in segments.enumerated() {
            guard !isCancelled, !Task.isCancelled else {
                throw TTSError.cancelled
            }

            let ext = provider == .elevenLabs ? "mp3" : "wav"
            let outputURL = outputDirectory.appendingPathComponent("segment_\(segment.index).\(ext)")

            let url = try await synthesize(
                text: segment.text,
                modelName: modelName,
                provider: provider,
                speed: speed,
                pitch: pitch,
                emotion: emotion,
                apiURL: apiURL,
                apiPort: apiPort,
                outputURL: outputURL,
                options: options
            )
            results.append(url)
            progressHandler(Double(i + 1) / Double(segments.count))
        }

        return results
    }

    // MARK: - Available Models

    func availableModels(
        provider: TTSProvider,
        apiURL: String,
        apiPort: Int
    ) async throws -> [String] {
        switch provider {
        case .elevenLabs:
            return try await fetchElevenLabsVoices()

        case .silero, .kokoro, .qwenLocal:
            return try await fetchLocalModels(provider: provider)

        case .qwenCloud:
            return ["qwen3-tts-flash"]

        case .custom:
            return try await fetchCustomModels(apiURL: apiURL, apiPort: apiPort)
        }
    }

    // MARK: - Cancel

    func cancel() async {
        isCancelled = true
    }

    // MARK: - Private: ElevenLabs

    private func synthesizeElevenLabs(
        text: String,
        voiceId: String,
        speed: Double,
        outputURL: URL
    ) async throws -> URL {
        guard let apiKey = UserDefaults.standard.string(forKey: "elevenLabsAPIKey"), !apiKey.isEmpty else {
            throw TTSError.connectionFailed("ElevenLabs API key not configured. Set it in Settings.")
        }

        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)") else {
            throw TTSError.connectionFailed("Invalid voice ID: \(voiceId)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = max(Self.requestTimeout, Double(text.count) / 10)

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
                "speed": speed,
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.connectionFailed("Invalid response from ElevenLabs")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw TTSError.synthesisFaild("ElevenLabs API error: \(errorMsg)")
        }

        try data.write(to: outputURL)
        return outputURL
    }

    private func fetchElevenLabsVoices() async throws -> [String] {
        guard let apiKey = UserDefaults.standard.string(forKey: "elevenLabsAPIKey"), !apiKey.isEmpty else {
            throw TTSError.connectionFailed("ElevenLabs API key not configured")
        }

        guard let url = URL(string: "https://api.elevenlabs.io/v1/voices") else {
            throw TTSError.connectionFailed("Invalid ElevenLabs API URL")
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.timeoutInterval = Self.requestTimeout

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TTSError.connectionFailed("Failed to fetch ElevenLabs voices")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let voices = json["voices"] as? [[String: Any]] else {
            throw TTSError.connectionFailed("Invalid response format from ElevenLabs")
        }

        return voices.compactMap { voice -> String? in
            guard let voiceId = voice["voice_id"] as? String,
                  let name = voice["name"] as? String else { return nil }
            return "\(name) (\(voiceId))"
        }
    }

    // MARK: - Private: Qwen Cloud (DashScope API)

    private func synthesizeQwenCloud(
        text: String,
        modelName: String,
        speed: Double,
        emotion: String?,
        outputURL: URL
    ) async throws -> URL {
        guard let apiKey = UserDefaults.standard.string(forKey: "dashscopeAPIKey"), !apiKey.isEmpty else {
            throw TTSError.connectionFailed("DashScope API key not configured. Set it in Settings.")
        }

        guard let url = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/audio/speech") else {
            throw TTSError.connectionFailed("Invalid DashScope API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = max(Self.requestTimeout, Double(text.count) / 5)

        var body: [String: Any] = [
            "model": modelName.isEmpty ? "qwen3-tts-flash" : modelName,
            "input": text,
        ]

        if let emotion = emotion, !emotion.isEmpty {
            body["voice_instruct"] = emotion
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.connectionFailed("Invalid response from DashScope")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw TTSError.synthesisFaild("DashScope API error: \(errorMsg)")
        }

        try data.write(to: outputURL)
        return outputURL
    }

    // MARK: - Private: Local Providers (Silero/Kokoro/Qwen)

    /// Extract an inline emotion tag like `[happy]` from the beginning of text.
    /// Returns the tag value and the remaining clean text.
    private nonisolated func extractInlineEmotion(from text: String) -> (emotion: String?, cleanText: String) {
        let pattern = #"^\s*\[([a-zA-Z_]+)\]\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let tagRange = Range(match.range(at: 1), in: text) else {
            return (nil, text)
        }
        let tag = String(text[tagRange])
        let cleanText = String(text[text.index(text.startIndex, offsetBy: match.range.length)...])
        return (tag, cleanText)
    }

    private func synthesizeLocal(
        text: String,
        modelName: String,
        provider: TTSProvider,
        speed: Double,
        pitch: Double,
        emotion: String?,
        outputURL: URL,
        options: TTSGenerationOptions = .default
    ) async throws -> URL {
        let providerName: String
        switch provider {
        case .silero: providerName = "silero"
        case .kokoro: providerName = "kokoro"
        case .qwenLocal: providerName = "qwen"
        default: providerName = "silero"
        }
        let port = try await LocalServerManager.shared.ensureTTSServer(provider: providerName)

        guard let url = URL(string: "http://127.0.0.1:\(port)/api/tts") else {
            throw TTSError.connectionFailed("Invalid local server URL")
        }

        // Extract inline [tag] from preprocessed text (e.g. "[whisper] Hello" → tag="whisper", clean="Hello")
        let (inlineEmotion, cleanText) = extractInlineEmotion(from: text)
        // Per-segment inline emotion takes priority over global emotion setting
        let effectiveEmotion = inlineEmotion ?? emotion ?? ""

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Qwen: first request loads the model (3-5 min download + load), subsequent ~10-30s
        // Silero/Kokoro: much faster
        if provider == .qwenLocal {
            request.timeoutInterval = max(Self.qwenFirstRequestTimeout, Double(cleanText.count))
        } else {
            request.timeoutInterval = max(Self.requestTimeout * 2, Double(cleanText.count) / 2)
        }

        var body: [String: Any] = [
            "text": cleanText,
            "model": modelName,
            "speed": speed,
            "pitch": pitch,
            "emotion": effectiveEmotion,
        ]

        // Add extended generation options
        if !options.speaker.isEmpty {
            body["speaker"] = options.speaker
        }
        if !options.language.isEmpty {
            body["language"] = options.language
        }
        if options.temperature > 0 {
            body["temperature"] = options.temperature
        }
        if options.topK > 0 {
            body["top_k"] = options.topK
        }
        if options.topP > 0 {
            body["top_p"] = options.topP
        }
        if options.repetitionPenalty > 0 {
            body["repetition_penalty"] = options.repetitionPenalty
        }
        body["do_sample"] = options.doSample
        if options.maxNewTokens > 0 {
            body["max_new_tokens"] = options.maxNewTokens
        }
        // Voice cloning fields (Qwen Base models)
        if !options.referenceAudioPath.isEmpty {
            body["ref_audio_path"] = options.referenceAudioPath
        }
        if !options.referenceText.isEmpty {
            body["ref_text"] = options.referenceText
        }
        if options.xVectorOnlyMode {
            body["x_vector_only_mode"] = true
        }
        // Subtalker parameters (voice cloning)
        if options.subtalkerTemperature > 0 {
            body["subtalker_temperature"] = options.subtalkerTemperature
        }
        if options.subtalkerTopK > 0 {
            body["subtalker_top_k"] = options.subtalkerTopK
        }
        if options.subtalkerTopP > 0 {
            body["subtalker_top_p"] = options.subtalkerTopP
        }
        body["subtalker_dosample"] = options.subtalkerDoSample

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.connectionFailed("Invalid response from local TTS server")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw TTSError.synthesisFaild("Local TTS error: \(errorMsg)")
        }

        try data.write(to: outputURL)
        return outputURL
    }

    private func fetchLocalModels(provider: TTSProvider) async throws -> [String] {
        let providerName: String
        switch provider {
        case .silero: providerName = "silero"
        case .kokoro: providerName = "kokoro"
        case .qwenLocal: providerName = "qwen"
        default: providerName = "silero"
        }
        let port = try await LocalServerManager.shared.ensureTTSServer(provider: providerName)

        guard let url = URL(string: "http://127.0.0.1:\(port)/api/models") else {
            throw TTSError.connectionFailed("Invalid local server URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TTSError.connectionFailed("Failed to fetch models from local server")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [String] else {
            throw TTSError.connectionFailed("Invalid response from local server")
        }

        return models
    }

    // MARK: - Private: Custom API

    private func synthesizeCustomAPI(
        text: String,
        modelName: String,
        speed: Double,
        pitch: Double,
        emotion: String?,
        apiURL: String,
        apiPort: Int,
        outputURL: URL
    ) async throws -> URL {
        guard let url = URL(string: "\(apiURL):\(apiPort)/api/tts") else {
            throw TTSError.connectionFailed("Invalid API URL: \(apiURL):\(apiPort)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = max(Self.requestTimeout, Double(text.count) / 5)

        let body: [String: Any] = [
            "text": text,
            "model": modelName,
            "speed": speed,
            "pitch": pitch,
            "emotion": emotion ?? "",
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.connectionFailed("Invalid response from custom API")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw TTSError.synthesisFaild("Custom API error: \(errorMsg)")
        }

        try data.write(to: outputURL)
        return outputURL
    }

    private func fetchCustomModels(apiURL: String, apiPort: Int) async throws -> [String] {
        guard let url = URL(string: "\(apiURL):\(apiPort)/api/models") else {
            throw TTSError.connectionFailed("Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TTSError.connectionFailed("Failed to fetch models from custom API")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [String] else {
            return ["default"]
        }

        return models
    }

    // MARK: - Private: Network Helper

    private nonisolated func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw TTSError.connectionFailed(
                    "Превышено время ожидания ответа от TTS-сервера. "
                    + "При первом запуске модель загружается в память — это может занять несколько минут. "
                    + "Попробуйте ещё раз."
                )
            case .cannotConnectToHost, .networkConnectionLost:
                throw TTSError.connectionFailed(
                    "Не удалось подключиться к TTS-серверу: \(error.localizedDescription)"
                )
            default:
                throw TTSError.connectionFailed(error.localizedDescription)
            }
        } catch {
            throw TTSError.connectionFailed(error.localizedDescription)
        }
    }
}
