//
//  BookVoiceTests.swift
//  BookVoiceTests
//
//  Created by Павел Афонин on 22.02.2026.
//

import Foundation
import Testing
@testable import BookVoice

struct BookVoiceTests {

    @Test
    func project_defaults_areInitialized() {
        let project = VoiceoverProject()

        #expect(project.status == .draft)
        #expect(project.currentStep == 1)
        #expect(project.ttsProvider == .silero)
        #expect(project.segmentationStrategy == .byParagraph)
        #expect(project.rvcEnabled == false)
    }

    @Test
    func history_filteredProjects_filtersBySearchAndStatus() {
        let draft = VoiceoverProject(title: "Alice in Wonder")
        draft.author = "Lewis Carroll"
        draft.status = .draft

        let completed = VoiceoverProject(title: "Moby Dick")
        completed.author = "Herman Melville"
        completed.status = .completed

        let vm = HistoryViewModel()
        vm.searchText = "alice"
        vm.selectedStatus = .draft

        let result = vm.filteredProjects([draft, completed])
        #expect(result.count == 1)
        #expect(result.first?.title == "Alice in Wonder")
    }

    @Test
    func textUpload_segmentText_populatesCountAndPreview() async {
        let project = VoiceoverProject()
        let service = StubTextProcessingService(
            segments: ["s1", "s2", "s3", "s4", "s5", "s6"],
            allSegments: ["s1", "s2", "s3", "s4", "s5", "s6"]
        )
        let vm = TextUploadViewModel(project: project, textService: service)
        vm.rawText = "Some raw text"

        await vm.segmentText()

        #expect(vm.totalSegmentCount == 6)
        #expect(vm.previewSegments.count == AppConstants.maxPreviewSegments)
        #expect(vm.previewSegments.first == "s1")
        #expect(vm.errorMessage == nil)
    }

    @Test
    func textUpload_allSegments_returnsEmptyOnError() async {
        let project = VoiceoverProject()
        let service = StubTextProcessingService(
            segments: [],
            allSegments: [],
            allSegmentsError: TextProcessingError.segmentationFailed("boom")
        )
        let vm = TextUploadViewModel(project: project, textService: service)
        vm.rawText = "abc"

        let result = await vm.allSegments()
        #expect(result.isEmpty)
    }

    @Test
    func voiceover_qwenFeatureFlags_matchModelType() {
        let project = VoiceoverProject()
        project.ttsProvider = .qwenLocal
        let vm = VoiceoverViewModel(
            project: project,
            ttsService: MockTTSService(),
            notificationService: MockNotificationService()
        )

        vm.selectedModel = "1.7B-Base"
        #expect(vm.qwenModelType == "base")
        #expect(vm.supportsReferenceVoice == true)
        #expect(vm.supportsSpeakerSelection == false)

        vm.selectedModel = "0.6B-CustomVoice"
        #expect(vm.qwenModelType == "custom_voice")
        #expect(vm.supportsReferenceVoice == false)
        #expect(vm.supportsSpeakerSelection == true)
        #expect(vm.supportsEmotion == true)
    }

    @Test
    func voiceover_prepareSegments_setsPreviewAndTotals() {
        let project = VoiceoverProject()
        let vm = VoiceoverViewModel(
            project: project,
            ttsService: MockTTSService(),
            notificationService: MockNotificationService()
        )

        let longText = String(repeating: "a", count: 120)
        vm.prepareSegments([longText, "short"])

        #expect(vm.totalSegments == 2)
        #expect(vm.segmentStates.count == 2)
        #expect(vm.segmentStates[0].previewText.count == 80)
        #expect(vm.segmentStates[1].previewText == "short")
    }

    @Test
    func voiceover_updateFromProject_resetsModelListOnProviderChange() {
        let project = VoiceoverProject()
        project.ttsProvider = .silero
        project.ttsModelName = "v4_ru"

        let vm = VoiceoverViewModel(
            project: project,
            ttsService: MockTTSService(),
            notificationService: MockNotificationService()
        )
        vm.availableModels = ["v4_ru", "v3_en"]
        vm.errorMessage = "old error"

        let changed = VoiceoverProject()
        changed.ttsProvider = .qwenCloud
        changed.ttsModelName = "qwen3-tts-flash"
        changed.apiURL = "https://example.com"
        changed.apiPort = 443

        vm.updateFromProject(changed)

        #expect(vm.provider == .qwenCloud)
        #expect(vm.selectedModel == "qwen3-tts-flash")
        #expect(vm.availableModels.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test
    func wizard_finalAudioURLs_prefersConvertedWhenEnabled() {
        let project = VoiceoverProject()
        let wizard = WizardViewModel(project: project, services: ServiceContainer(useMocks: true))

        let temp = FileManager.default.temporaryDirectory
        let original = temp.appendingPathComponent("original.wav")
        let converted = temp.appendingPathComponent("converted.wav")
        wizard.voiceover.segmentStates = [
            SegmentSynthesisState(id: 0, index: 0, fullText: "a", previewText: "a", status: .completed, audioURL: original),
        ]
        wizard.timbreChange.isEnabled = true
        wizard.timbreChange.convertedAudioURLs = [converted]

        #expect(wizard.finalAudioURLs == [converted])
    }

    @Test
    func wizard_goToNextStep_updatesStepAndProject() {
        let project = VoiceoverProject()
        let wizard = WizardViewModel(project: project, services: ServiceContainer(useMocks: true))

        wizard.currentStep = 2
        wizard.textUpload.rawText = "text"
        wizard.textUpload.totalSegmentCount = 1

        wizard.goToNextStep()

        #expect(wizard.currentStep == 3)
        #expect(project.currentStep == 3)
    }

    @Test
    func settings_loadModels_readsFromModelManager() async {
        let vm = SettingsViewModel(modelManager: MockModelManagerService())
        vm.modelDirectoryPath = FileManager.default.temporaryDirectory.path

        await vm.loadModels()

        #expect(vm.isLoadingModels == false)
        #expect(vm.models.count == 3)
    }

    @Test
    func modelSettings_isValid_forCustomProvider_dependsOnURLAndPort() {
        let project = VoiceoverProject()
        let vm = ModelSettingsViewModel(project: project, ttsService: MockTTSService())
        vm.selectedProvider = .custom

        vm.apiURL = ""
        vm.apiPort = 8080
        #expect(vm.isValid == false)

        vm.apiURL = "http://localhost"
        vm.apiPort = 0
        #expect(vm.isValid == false)

        vm.apiPort = 8080
        #expect(vm.isValid == true)
    }

    @Test
    func modelSettings_isValid_forCloudProviders_dependsOnConnectionFlag() {
        let project = VoiceoverProject()
        let vm = ModelSettingsViewModel(project: project, ttsService: MockTTSService())
        vm.selectedProvider = .elevenLabs
        vm.connectionTestSuccess = false
        #expect(vm.isValid == false)

        vm.connectionTestSuccess = true
        #expect(vm.isValid == true)
    }

    @Test
    func modelSettings_testConnection_successSetsResultAndFlag() async {
        let project = VoiceoverProject()
        let stub = StubTTSService(models: ["m1", "m2"])
        let vm = ModelSettingsViewModel(project: project, ttsService: stub)
        vm.selectedProvider = .custom

        await vm.testConnection()

        #expect(vm.isTestingConnection == false)
        #expect(vm.connectionTestSuccess == true)
        #expect(vm.connectionTestResult?.contains("Подключено!") == true)
        #expect(vm.connectionTestResult?.contains("Моделей: 2") == true)
    }

    @Test
    func modelSettings_testConnection_failureSetsErrorResult() async {
        let project = VoiceoverProject()
        let stub = StubTTSService(models: [], modelsError: TTSError.connectionFailed("down"))
        let vm = ModelSettingsViewModel(project: project, ttsService: stub)
        vm.selectedProvider = .custom

        await vm.testConnection()

        #expect(vm.isTestingConnection == false)
        #expect(vm.connectionTestSuccess == false)
        #expect(vm.connectionTestResult?.contains("Ошибка подключения") == true)
    }

    @Test
    func modelSettings_insertDefaultPrompt_setsDefaultAndFlag() {
        let project = VoiceoverProject()
        let vm = ModelSettingsViewModel(project: project, ttsService: MockTTSService())

        vm.systemPrompt = "custom"
        #expect(vm.hasDefaultPrompt == false)

        vm.insertDefaultPrompt()
        #expect(vm.systemPrompt == ModelSettingsViewModel.defaultSystemPrompt)
        #expect(vm.hasDefaultPrompt == true)
    }

    @Test
    func wizard_canGoForward_step3_requiresReadyAndNotSynthesizing() {
        let project = VoiceoverProject()
        let wizard = WizardViewModel(project: project, services: ServiceContainer(useMocks: true))
        wizard.currentStep = 3

        wizard.voiceover.segmentStates = [
            SegmentSynthesisState(id: 0, index: 0, fullText: "a", previewText: "a", status: .pending),
        ]
        wizard.voiceover.isSynthesizing = false
        #expect(wizard.canGoForward == false)

        wizard.voiceover.segmentStates[0].status = .completed
        #expect(wizard.canGoForward == true)

        wizard.voiceover.isSynthesizing = true
        #expect(wizard.canGoForward == false)
    }

    @Test
    func wizard_canGoForward_step4_requiresValidAndNotConverting() {
        let project = VoiceoverProject()
        let wizard = WizardViewModel(project: project, services: ServiceContainer(useMocks: true))
        wizard.currentStep = 4
        wizard.timbreChange.isEnabled = true
        wizard.timbreChange.modelPath = ""
        wizard.timbreChange.isConverting = false
        #expect(wizard.canGoForward == false)

        wizard.timbreChange.modelPath = "model.pth"
        #expect(wizard.canGoForward == true)

        wizard.timbreChange.isConverting = true
        #expect(wizard.canGoForward == false)
    }

    @Test
    func wizard_goToStep_allowsVisitedStepsAndBlocksFutureStep() {
        let project = VoiceoverProject()
        project.currentStep = 2
        let wizard = WizardViewModel(project: project, services: ServiceContainer(useMocks: true))
        wizard.currentStep = 2

        wizard.goToStep(1)
        #expect(wizard.currentStep == 1)

        wizard.goToStep(4)
        #expect(wizard.currentStep == 1)
    }

    @Test
    func serviceContainer_useMocks_usesMockServices() {
        let container = ServiceContainer(useMocks: true)

        #expect(container.textProcessing is MockTextProcessingService)
        #expect(container.tts is MockTTSService)
        #expect(container.rvc is MockRVCService)
        #expect(container.modelManager is MockModelManagerService)
        #expect(container.notification is MockNotificationService)
    }

    @Test
    func timbreChange_isValid_dependsOnEnabledAndModelPath() {
        let project = VoiceoverProject()
        let vm = TimbreChangeViewModel(
            project: project,
            rvcService: MockRVCService(),
            modelManager: MockModelManagerService(),
            audioEngine: MockAudioEngineService(),
            notificationService: MockNotificationService()
        )

        vm.isEnabled = false
        vm.modelPath = ""
        #expect(vm.isValid == true)

        vm.isEnabled = true
        vm.modelPath = ""
        #expect(vm.isValid == false)

        vm.modelPath = "voice.pth"
        #expect(vm.isValid == true)
    }

    @Test
    func postProcessing_canExport_dependsOnTitle() {
        let project = VoiceoverProject()
        let vm = PostProcessingViewModel(
            project: project,
            audioEngine: MockAudioEngineService(),
            notificationService: MockNotificationService()
        )

        vm.metadataTitle = ""
        #expect(vm.canExport == false)

        vm.metadataTitle = "Book"
        #expect(vm.canExport == true)
    }

    @Test
    func textUpload_saveToProject_persistsCurrentFields() {
        let project = VoiceoverProject()
        let vm = TextUploadViewModel(project: project, textService: MockTextProcessingService())
        vm.rawText = "hello"
        vm.fileName = "book.txt"
        vm.strategy = .fixedLength
        vm.fixedLength = 111

        vm.saveToProject(project)

        #expect(project.rawText == "hello")
        #expect(project.sourceFileName == "book.txt")
        #expect(project.segmentationStrategy == .fixedLength)
        #expect(project.fixedSegmentLength == 111)
        #expect(project.status == .textLoaded)
    }

    @Test
    func settings_formatFileSize_returnsReadableString() {
        let vm = SettingsViewModel(modelManager: MockModelManagerService())
        let value = vm.formatFileSize(1_024)
        #expect(value.isEmpty == false)
    }

    @Test
    func liveTextProcessing_segment_byParagraph_trimsAndSkipsEmpty() async throws {
        let service = LiveTextProcessingService()
        let text = "  First paragraph  \n\n\n\n Second paragraph \n\n  Third "

        let segments = try await service.segment(
            text: text,
            strategy: .byParagraph,
            fixedLength: 100
        )

        #expect(segments.count == 3)
        #expect(segments[0] == "First paragraph")
        #expect(segments[1] == "Second paragraph")
        #expect(segments[2] == "Third")
    }

    @Test
    func liveTextProcessing_segment_fixedLength_splitsByWordCount() async throws {
        let service = LiveTextProcessingService()
        let text = "one two three four five"

        let segments = try await service.segment(
            text: text,
            strategy: .fixedLength,
            fixedLength: 2
        )

        #expect(segments == ["one two", "three four", "five"])
    }

    @Test
    func liveTextProcessing_detectChapters_findsEnglishAndRomanTitles() async throws {
        let service = LiveTextProcessingService()
        let text = """
        Chapter I. Intro
        Text one.

        CHAPTER 2: Next
        Text two.
        """

        let chapters = try await service.detectChapters(in: text)
        #expect(chapters.count == 2)
        #expect(chapters[0].title.contains("Chapter I"))
        #expect(chapters[1].title.contains("CHAPTER 2"))
    }

    @Test
    func liveTextProcessing_loadText_unsupportedType_throws() async {
        let service = LiveTextProcessingService()
        let url = URL(fileURLWithPath: "/tmp/file.unsupported")

        do {
            _ = try await service.loadText(from: url)
            Issue.record("Expected unsupported file type error")
        } catch let error as TextProcessingError {
            if case .unsupportedFileType(let ext) = error {
                #expect(ext == "unsupported")
            } else {
                Issue.record("Unexpected TextProcessingError case")
            }
        } catch {
            Issue.record("Unexpected error type")
        }
    }

    @Test
    func mockTTS_synthesizeBatch_createsFilesAndReportsProgress() async throws {
        let service = MockTTSService()
        let outputDir = try makeTempDirectory()
        var progressValues: [Double] = []

        let urls = try await service.synthesizeBatch(
            segments: [(0, "hello world"), (1, "second segment")],
            modelName: "v4_ru",
            provider: .silero,
            speed: 1.0,
            pitch: 1.0,
            emotion: nil,
            apiURL: "http://localhost",
            apiPort: 8100,
            outputDirectory: outputDir,
            options: .default,
            progressHandler: { progressValues.append($0) }
        )

        #expect(urls.count == 2)
        #expect(progressValues.last == 1.0)
        #expect(FileManager.default.fileExists(atPath: urls[0].path))
        #expect(FileManager.default.fileExists(atPath: urls[1].path))
    }

    @Test
    func mockRVC_convertBatch_createsOutputAndReportsProgress() async throws {
        let service = MockRVCService()
        let inputDir = try makeTempDirectory()
        let outputDir = try makeTempDirectory()

        let input1 = inputDir.appendingPathComponent("a.wav")
        let input2 = inputDir.appendingPathComponent("b.wav")
        try Data([1, 2, 3]).write(to: input1)
        try Data([4, 5, 6]).write(to: input2)

        var progressValues: [Double] = []
        let urls = try await service.convertBatch(
            inputURLs: [input1, input2],
            outputDirectory: outputDir,
            modelPath: "model.pth",
            indexRate: 0.75,
            filterRadius: 3,
            protectVoiceless: 0.33,
            progressHandler: { progressValues.append($0) }
        )

        #expect(urls.count == 2)
        #expect(progressValues.last == 1.0)
        #expect(FileManager.default.fileExists(atPath: urls[0].path))
        #expect(FileManager.default.fileExists(atPath: urls[1].path))
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private nonisolated final class StubTTSService: TTSService, Sendable {
    let models: [String]
    let modelsError: Error?

    init(models: [String], modelsError: Error? = nil) {
        self.models = models
        self.modelsError = modelsError
    }

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
        options: TTSGenerationOptions
    ) async throws -> URL {
        outputURL
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
        options: TTSGenerationOptions,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> [URL] {
        []
    }

    func availableModels(
        provider: TTSProvider,
        apiURL: String,
        apiPort: Int
    ) async throws -> [String] {
        if let modelsError {
            throw modelsError
        }
        return models
    }

    func cancel() async {}
}

private nonisolated final class StubTextProcessingService: TextProcessingService, Sendable {
    let segments: [String]
    let allSegments: [String]
    let allSegmentsError: Error?

    init(segments: [String], allSegments: [String], allSegmentsError: Error? = nil) {
        self.segments = segments
        self.allSegments = allSegments
        self.allSegmentsError = allSegmentsError
    }

    func loadText(from url: URL) async throws -> String {
        "text"
    }

    func segment(
        text: String,
        strategy: SegmentationStrategy,
        fixedLength: Int
    ) async throws -> [String] {
        if let allSegmentsError {
            throw allSegmentsError
        }
        if strategy == .fixedLength {
            return allSegments
        }
        return segments
    }

    func detectChapters(in text: String) async throws -> [(title: String, range: Range<String.Index>)] {
        []
    }

}
