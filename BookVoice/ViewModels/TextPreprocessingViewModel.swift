//
//  TextPreprocessingViewModel.swift
//  BookVoice
//

import SwiftUI

@Observable
final class TextPreprocessingViewModel {

    // MARK: - LLM Configuration

    var selectedProvider: LLMProvider = .openai
    var selectedModel: String = ""
    var customPrompt: String = ""
    var isEnabled: Bool = false  // по умолчанию шаг выключен

    // MARK: - Model Management

    var availableModels: [String] = []
    var isLoadingModels = false

    // MARK: - Connection Status

    var connectionStatus: ConnectionStatus = .unknown

    enum ConnectionStatus: Equatable {
        case unknown
        case checking
        case connected
        case failed(String)
    }

    // MARK: - Download

    var isDownloading = false
    var downloadProgress: Double = 0
    var downloadedMB: Double = 0
    var downloadTotalMB: Double = 0

    // MARK: - State

    var isProcessing = false
    var progress: Double = 0
    var currentSegmentIndex: Int = 0
    var totalSegments: Int = 0
    var errorMessage: String?

    // MARK: - Data

    var originalSegments: [String] = []
    var processedSegments: [String] = []
    var segmentStates: [PreprocessingSegmentState] = []

    /// Выбранный сегмент для детального просмотра
    var selectedSegmentIndex: Int?

    // MARK: - Computed

    var isValid: Bool {
        !isEnabled || !processedSegments.isEmpty
    }

    var effectivePrompt: String {
        customPrompt.isEmpty ? Self.defaultPrompt : customPrompt
    }

    /// Сегменты для передачи на озвучку: обработанные (если есть) или оригинальные
    var outputSegments: [String] {
        if !isEnabled || processedSegments.isEmpty {
            return originalSegments
        }
        return processedSegments
    }

    // MARK: - Dependencies

    private let llmService: any LLMService
    private var processingTask: Task<Void, Never>?

    // MARK: - Recommended Models

    struct RecommendedModel: Identifiable {
        let id: String
        let displayName: String
        let repoId: String
        let filename: String
        let sizeGB: Double
    }

    static let recommendedModels: [RecommendedModel] = [
        RecommendedModel(
            id: "qwen2.5-3b-instruct",
            displayName: "Qwen 2.5 3B (рекомендуемая)",
            repoId: "Qwen/Qwen2.5-3B-Instruct-GGUF",
            filename: "qwen2.5-3b-instruct-q4_k_m.gguf",
            sizeGB: 2.0
        ),
        RecommendedModel(
            id: "qwen2.5-7b-instruct",
            displayName: "Qwen 2.5 7B (лучше качество)",
            repoId: "bartowski/Qwen2.5-7B-Instruct-GGUF",
            filename: "Qwen2.5-7B-Instruct-Q4_K_M.gguf",
            sizeGB: 4.7
        ),
        RecommendedModel(
            id: "gemma-2-2b-it",
            displayName: "Gemma 2 2B (лёгкая)",
            repoId: "bartowski/gemma-2-2b-it-GGUF",
            filename: "gemma-2-2b-it-Q4_K_M.gguf",
            sizeGB: 1.7
        ),
    ]

    // MARK: - Init

    init(project: VoiceoverProject, llmService: any LLMService) {
        self.llmService = llmService

        // Восстановить из проекта
        if let provider = project.llmProvider {
            self.selectedProvider = provider
        }
        self.selectedModel = project.llmModel ?? ""
        self.customPrompt = project.llmCustomPrompt ?? ""
        self.isEnabled = !(project.llmSkipped ?? true)

        // Восстановить обработанные сегменты
        if let data = project.preprocessedSegmentsJSON,
           let segments = try? JSONDecoder().decode([String].self, from: data) {
            self.processedSegments = segments
        }
    }

    // MARK: - Connection & Models

    /// Проверить подключение и загрузить список моделей для текущего провайдера
    func checkConnectionAndLoadModels() async {
        connectionStatus = .checking
        isLoadingModels = true
        errorMessage = nil

        do {
            _ = try await llmService.checkConnection(provider: selectedProvider)
            connectionStatus = .connected
            let models = try await llmService.availableModels(provider: selectedProvider)
            availableModels = models
        } catch {
            connectionStatus = .failed(error.localizedDescription)
            availableModels = []
        }

        isLoadingModels = false

        // Если текущая модель не в списке, выбрать первую или дефолтную
        if !availableModels.contains(selectedModel) {
            selectedModel = availableModels.first ?? selectedProvider.defaultModel
        }
    }

    /// Скачать модель (для локального провайдера)
    func downloadModel(_ model: RecommendedModel) async {
        isDownloading = true
        downloadProgress = 0
        downloadedMB = 0
        downloadTotalMB = model.sizeGB * 1000 // GB → MB
        errorMessage = nil

        let expectedBytes = Int(model.sizeGB * 1_000_000_000)

        // Параллельная задача: опрашивать прогресс загрузки
        let progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self else { break }
                if let progress = await self.llmService.downloadProgress() {
                    await MainActor.run {
                        self.downloadProgress = progress
                        self.downloadedMB = progress * self.downloadTotalMB
                    }
                }
            }
        }

        do {
            try await llmService.downloadModel(
                repoId: model.repoId,
                filename: model.filename,
                expectedSizeBytes: expectedBytes
            )
            downloadProgress = 1.0
            downloadedMB = downloadTotalMB
            // После скачивания — обновить список моделей
            await checkConnectionAndLoadModels()
        } catch {
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
        }

        progressTask.cancel()
        isDownloading = false
    }

    // MARK: - Segment Preparation

    func prepareSegments(_ segments: [String]) {
        // Если сегменты изменились (другая сегментация на шаге 2),
        // сбрасываем обработанные данные
        if originalSegments != segments {
            processedSegments = []
        }

        originalSegments = segments
        totalSegments = segments.count

        segmentStates = segments.enumerated().map { i, text in
            let processed = i < processedSegments.count ? processedSegments[i] : nil
            return PreprocessingSegmentState(
                id: i,
                index: i,
                originalText: text,
                processedText: processed,
                status: processed != nil ? .completed : .pending
            )
        }
    }

    // MARK: - Processing

    func processAll() async {
        guard !originalSegments.isEmpty else { return }

        isProcessing = true
        progress = 0
        errorMessage = nil
        currentSegmentIndex = 0

        // Обнулить статусы
        for i in segmentStates.indices {
            segmentStates[i].status = .pending
            segmentStates[i].processedText = nil
        }
        processedSegments = []

        let model = selectedModel.isEmpty ? selectedProvider.defaultModel : selectedModel

        processingTask = Task {
            do {
                let results = try await llmService.preprocessBatch(
                    segments: originalSegments,
                    systemPrompt: effectivePrompt,
                    provider: selectedProvider,
                    model: model,
                    progressHandler: { [weak self] prog in
                        guard let self else { return }
                        Task { @MainActor in
                            self.progress = prog
                            let completed = Int(prog * Double(self.totalSegments))
                            self.currentSegmentIndex = min(completed, self.totalSegments - 1)
                        }
                    }
                )

                processedSegments = results
                for (i, text) in results.enumerated() where i < segmentStates.count {
                    segmentStates[i].status = .completed
                    segmentStates[i].processedText = text
                }
            } catch {
                if !(error is CancellationError) {
                    errorMessage = error.localizedDescription
                }
                // Пометить необработанные как pending
                for i in segmentStates.indices where segmentStates[i].status == .inProgress {
                    segmentStates[i].status = .pending
                }
            }
            isProcessing = false
        }
    }

    func cancelProcessing() async {
        processingTask?.cancel()
        await llmService.cancel()
        isProcessing = false
    }

    /// Переобработать один сегмент
    func reprocessSegment(_ index: Int) async {
        guard index < originalSegments.count else { return }
        segmentStates[index].status = .inProgress

        let model = selectedModel.isEmpty ? selectedProvider.defaultModel : selectedModel

        do {
            let result = try await llmService.preprocessSegment(
                text: originalSegments[index],
                systemPrompt: effectivePrompt,
                provider: selectedProvider,
                model: model
            )
            segmentStates[index].processedText = result
            segmentStates[index].status = .completed

            // Обновить массив результатов
            while processedSegments.count <= index {
                processedSegments.append("")
            }
            processedSegments[index] = result
        } catch {
            segmentStates[index].status = .failed
            errorMessage = error.localizedDescription
        }
    }

    /// Ручное редактирование обработанного сегмента
    func updateProcessedSegment(_ index: Int, text: String) {
        guard index < segmentStates.count else { return }
        segmentStates[index].processedText = text

        while processedSegments.count <= index {
            processedSegments.append("")
        }
        processedSegments[index] = text
    }

    // MARK: - Persistence

    func saveToProject(_ project: VoiceoverProject) {
        project.llmProvider = selectedProvider
        project.llmModel = selectedModel.isEmpty ? nil : selectedModel
        project.llmCustomPrompt = customPrompt.isEmpty ? nil : customPrompt
        project.llmSkipped = !isEnabled  // инвертируем для обратной совместимости

        if !processedSegments.isEmpty {
            project.preprocessedSegmentsJSON = try? JSONEncoder().encode(processedSegments)
        } else {
            project.preprocessedSegmentsJSON = nil
        }

        project.updatedAt = Date()
    }

    // MARK: - Default Prompt

    static let defaultPrompt = """
    Ты — ассистент по подготовке текста для синтеза речи (TTS). \
    Твоя задача — разметить текст, чтобы он звучал более естественно при озвучке.

    Правила разметки:

    1. УДАРЕНИЯ: На словах с неоднозначным ударением поставь знак ударения \
    (комбинирующий акут U+0301) после ударной гласной.
       Примеры: замо́к (не за́мок), больши́е, доро́га
       НЕ ставь ударения на односложных словах и на словах, где ударение однозначно.

    2. ПАУЗЫ: Добавляй "..." (три точки) там, где нужна выразительная пауза:
       - Перед важным словом или поворотом сюжета
       - После обращения ("Дорогие друзья... мы собрались здесь")
       - В местах, где читатель бы сделал паузу

    3. ИНТОНАЦИЯ: Добавляй теги эмоций в квадратных скобках перед фразой, \
    которая требует особой интонации:
       [грустно], [радостно], [удивлённо], [испуганно], [торжественно], \
    [шёпотом], [сердито], [нежно], [иронично], [задумчиво]
       Используй теги ТОЛЬКО там, где интонация действительно отличается от нейтральной.

    ВАЖНО:
    - Не меняй слова, не перефразируй, не добавляй и не удаляй текст.
    - Возвращай ТОЛЬКО размеченный текст, без объяснений и комментариев.
    - Сохраняй все знаки препинания оригинала.
    - Не переусердствуй с разметкой — лучше меньше, но точнее.
    """
}

// MARK: - Segment State

struct PreprocessingSegmentState: Identifiable {
    let id: Int
    let index: Int
    let originalText: String
    var processedText: String?
    var status: Status = .pending

    enum Status {
        case pending
        case inProgress
        case completed
        case failed
    }

    var previewOriginal: String {
        String(originalText.prefix(100))
    }

    var previewProcessed: String? {
        processedText.map { String($0.prefix(100)) }
    }

    var statusIcon: String {
        switch status {
        case .pending: "circle"
        case .inProgress: "circle.dotted"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        }
    }

    var statusColor: Color {
        switch status {
        case .pending: .secondary
        case .inProgress: .blue
        case .completed: .green
        case .failed: .red
        }
    }
}
