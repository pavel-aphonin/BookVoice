//
//  LiveLLMService.swift
//  BookVoice
//
//  LLM service for text preprocessing via OpenAI, Claude (Anthropic), or local llama.cpp.
//

import Foundation

actor LiveLLMService: LLMService {

    private var isCancelled = false

    private static let requestTimeout: TimeInterval = 120
    private static let cloudDelayBetweenRequests: Duration = .milliseconds(500)
    private static let maxRetries = 3

    // MARK: - Public API

    func preprocessSegment(
        text: String,
        systemPrompt: String,
        provider: LLMProvider,
        model: String
    ) async throws -> String {
        try await callProvider(text: text, systemPrompt: systemPrompt, provider: provider, model: model)
    }

    func preprocessBatch(
        segments: [String],
        systemPrompt: String,
        provider: LLMProvider,
        model: String,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> [String] {
        isCancelled = false
        var results: [String] = []

        for (i, segment) in segments.enumerated() {
            guard !isCancelled, !Task.isCancelled else {
                throw LLMError.cancelled
            }

            let result = try await callWithRetry(
                text: segment,
                systemPrompt: systemPrompt,
                provider: provider,
                model: model
            )
            results.append(result)
            progressHandler(Double(i + 1) / Double(segments.count))

            // Delay between requests for cloud providers to respect rate limits
            if !provider.isLocal, i < segments.count - 1 {
                try? await Task.sleep(for: Self.cloudDelayBetweenRequests)
            }
        }

        return results
    }

    func cancel() {
        isCancelled = true
    }

    // MARK: - Model Management

    func availableModels(provider: LLMProvider) async throws -> [String] {
        switch provider {
        case .openai:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .claude:
            return ["claude-sonnet-4-20250514", "claude-haiku-4-20250414", "claude-3-5-sonnet-latest"]
        case .local:
            let port = try await LocalServerManager.shared.ensureLLMServer()
            guard let url = URL(string: "http://127.0.0.1:\(port)/api/models") else {
                throw LLMError.connectionFailed("Некорректный URL LLM-сервера")
            }
            let (data, _) = try await performRequest(URLRequest(url: url))
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [String] else {
                return []
            }
            return models
        }
    }

    func checkConnection(provider: LLMProvider) async throws -> Bool {
        switch provider {
        case .openai:
            guard let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey"), !apiKey.isEmpty else {
                throw LLMError.apiKeyMissing("OpenAI")
            }
            return true
        case .claude:
            guard let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey"), !apiKey.isEmpty else {
                throw LLMError.apiKeyMissing("Claude (Anthropic)")
            }
            return true
        case .local:
            let port = try await LocalServerManager.shared.ensureLLMServer()
            guard let url = URL(string: "http://127.0.0.1:\(port)/api/health") else {
                throw LLMError.connectionFailed("Некорректный URL LLM-сервера")
            }
            let (_, response) = try await performRequest(URLRequest(url: url))
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw LLMError.connectionFailed("LLM-сервер не отвечает")
            }
            return true
        }
    }

    func downloadModel(repoId: String, filename: String, expectedSizeBytes: Int) async throws {
        let port = try await LocalServerManager.shared.ensureLLMServer()
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/download") else {
            throw LLMError.connectionFailed("Некорректный URL LLM-сервера")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "repo_id": repoId,
            "filename": filename,
            "expected_size_bytes": expectedSizeBytes,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            print("[LLM] Download request failed: HTTP \(statusCode), body: \(body)")
            throw LLMError.processingFailed(
                "Не удалось начать загрузку модели (HTTP \(statusCode)): \(body)"
            )
        }

        // Poll for download completion
        let statusURL = URL(string: "http://127.0.0.1:\(port)/api/download/status")!
        let deadline = Date().addingTimeInterval(3600) // 1 hour max

        while Date() < deadline {
            try? await Task.sleep(for: .seconds(2))

            let (statusData, _) = try await performRequest(URLRequest(url: statusURL))
            if let json = try? JSONSerialization.jsonObject(with: statusData) as? [String: Any] {
                if let error = json["error"] as? String, !error.isEmpty {
                    throw LLMError.processingFailed("Ошибка загрузки: \(error)")
                }
                if let active = json["active"] as? Bool, !active,
                   let progress = json["progress"] as? Double, progress >= 1.0 {
                    return // Download complete
                }
            }
        }

        throw LLMError.processingFailed("Превышено время ожидания загрузки модели")
    }

    func downloadProgress() async -> Double? {
        guard let port = await LocalServerManager.shared.getPort(for: .llm) else {
            return nil
        }
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/download/status") else {
            return nil
        }

        do {
            let (data, _) = try await performRequest(URLRequest(url: url))
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let active = json["active"] as? Bool, active,
               let progress = json["progress"] as? Double {
                return progress
            }
        } catch {
            // Ignore
        }
        return nil
    }

    func deleteModel(filename: String) async throws {
        let port = try await LocalServerManager.shared.ensureLLMServer()
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/delete") else {
            throw LLMError.connectionFailed("Некорректный URL LLM-сервера")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = ["filename": filename]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "<no body>"
            throw LLMError.processingFailed(
                "Не удалось удалить модель (HTTP \(statusCode)): \(responseBody)"
            )
        }
    }

    func installedModelsInfo() async throws -> [InstalledModelInfo] {
        let port = try await LocalServerManager.shared.ensureLLMServer()
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/models/info") else {
            throw LLMError.connectionFailed("Некорректный URL LLM-сервера")
        }

        let (data, _) = try await performRequest(URLRequest(url: url))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }

        return models.compactMap { dict in
            guard let filename = dict["filename"] as? String,
                  let sizeGB = dict["size_gb"] as? Double else { return nil }
            let isLoaded = dict["loaded"] as? Bool ?? false
            return InstalledModelInfo(filename: filename, sizeGB: sizeGB, isLoaded: isLoaded)
        }
    }

    // MARK: - Retry Logic

    private func callWithRetry(
        text: String,
        systemPrompt: String,
        provider: LLMProvider,
        model: String
    ) async throws -> String {
        var lastError: Error?

        for attempt in 1...Self.maxRetries {
            do {
                return try await callProvider(
                    text: text,
                    systemPrompt: systemPrompt,
                    provider: provider,
                    model: model
                )
            } catch let error as LLMError {
                lastError = error
                if case .rateLimited(let retryAfter) = error {
                    let delay = retryAfter ?? Double(attempt * 2)
                    print("[LLM] Rate limited, waiting \(Int(delay))s before retry \(attempt)/\(Self.maxRetries)")
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }
                throw error
            } catch {
                throw error
            }
        }

        throw lastError ?? LLMError.processingFailed("Превышено число попыток")
    }

    // MARK: - Provider Routing

    private func callProvider(
        text: String,
        systemPrompt: String,
        provider: LLMProvider,
        model: String
    ) async throws -> String {
        switch provider {
        case .openai:
            return try await callOpenAI(text: text, systemPrompt: systemPrompt, model: model)
        case .claude:
            return try await callClaude(text: text, systemPrompt: systemPrompt, model: model)
        case .local:
            return try await callLocal(text: text, systemPrompt: systemPrompt, model: model)
        }
    }

    // MARK: - OpenAI

    private func callOpenAI(text: String, systemPrompt: String, model: String) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey"), !apiKey.isEmpty else {
            throw LLMError.apiKeyMissing("OpenAI")
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw LLMError.connectionFailed("Некорректный URL OpenAI API")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Self.requestTimeout

        let body: [String: Any] = [
            "model": model.isEmpty ? LLMProvider.openai.defaultModel : model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.3,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)
        try checkHTTPResponse(response, provider: "OpenAI")

        return try parseOpenAIResponse(data)
    }

    private nonisolated func parseOpenAIResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMError.invalidResponse("Не удалось разобрать ответ OpenAI")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Claude (Anthropic)

    private func callClaude(text: String, systemPrompt: String, model: String) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey"), !apiKey.isEmpty else {
            throw LLMError.apiKeyMissing("Claude (Anthropic)")
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw LLMError.connectionFailed("Некорректный URL Anthropic API")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = Self.requestTimeout

        let body: [String: Any] = [
            "model": model.isEmpty ? LLMProvider.claude.defaultModel : model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": text],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)
        try checkHTTPResponse(response, provider: "Claude")

        return try parseClaudeResponse(data)
    }

    private nonisolated func parseClaudeResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String
        else {
            throw LLMError.invalidResponse("Не удалось разобрать ответ Claude")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Local (llama.cpp)

    private func callLocal(text: String, systemPrompt: String, model: String) async throws -> String {
        let port = try await LocalServerManager.shared.ensureLLMServer()
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/chat") else {
            throw LLMError.connectionFailed("Некорректный URL LLM-сервера")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Self.requestTimeout

        let body: [String: Any] = [
            "text": text,
            "system_prompt": systemPrompt,
            "model": model,
            "temperature": LLMModelCatalog.defaultTemperature,
            "max_tokens": LLMModelCatalog.defaultMaxTokens,
            "top_p": LLMModelCatalog.defaultTopP,
            "top_k": LLMModelCatalog.defaultTopK,
            "repeat_penalty": LLMModelCatalog.defaultRepeatPenalty,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)
        try checkHTTPResponse(response, provider: "Local LLM")

        return try parseLocalResponse(data)
    }

    private nonisolated func parseLocalResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? String
        else {
            throw LLMError.invalidResponse("Не удалось разобрать ответ локальной LLM")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private nonisolated func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.connectionFailed(error.localizedDescription)
        }
    }

    private nonisolated func checkHTTPResponse(_ response: URLResponse, provider: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.connectionFailed("Не HTTP-ответ от \(provider)")
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw LLMError.apiKeyMissing("\(provider) — ключ невалиден или отозван")
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw LLMError.rateLimited(retryAfter: retryAfter)
        default:
            throw LLMError.processingFailed("\(provider) вернул HTTP \(http.statusCode)")
        }
    }
}
