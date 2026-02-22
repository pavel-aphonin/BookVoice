//
//  VoiceoverViewModel.swift
//  BookVoice
//

import Foundation

struct SegmentSynthesisState: Identifiable {
    let id: Int
    let index: Int
    let previewText: String
    var status: Status = .pending
    var audioURL: URL?

    enum Status {
        case pending, inProgress, completed, failed
    }

    var statusIcon: String {
        switch status {
        case .pending: "circle"
        case .inProgress: "arrow.clockwise.circle"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    var statusColor: SwiftUI.Color {
        switch status {
        case .pending: .secondary
        case .inProgress: .orange
        case .completed: .green
        case .failed: .red
        }
    }

    var isCompleted: Bool { status == .completed }
}

import SwiftUI

@Observable
final class VoiceoverViewModel {
    var selectedModel: String = ""
    var availableModels: [String] = []
    var speed: Double
    var pitch: Double
    var emotion: String = ""

    var isSynthesizing = false
    var progress: Double = 0
    var currentSegmentIndex: Int = 0
    var totalSegments: Int = 0
    var segmentStates: [SegmentSynthesisState] = []
    var errorMessage: String?
    var isLoadingModels = false

    var isReady: Bool {
        segmentStates.allSatisfy { $0.isCompleted }
    }

    private let ttsService: any TTSService
    private let provider: TTSProvider
    private let apiURL: String
    private let apiPort: Int
    private var synthesisTask: Task<Void, Never>?

    init(project: VoiceoverProject, ttsService: any TTSService) {
        self.ttsService = ttsService
        self.speed = project.ttsSpeed
        self.pitch = project.ttsPitch
        self.emotion = project.ttsEmotion ?? ""
        self.provider = project.ttsProvider
        self.apiURL = project.apiURL
        self.apiPort = project.apiPort
        self.selectedModel = project.ttsModelName ?? ""
    }

    func loadModels() async {
        isLoadingModels = true
        do {
            availableModels = try await ttsService.availableModels(
                provider: provider,
                apiURL: apiURL,
                apiPort: apiPort
            )
            if selectedModel.isEmpty, let first = availableModels.first {
                selectedModel = first
            }
        } catch {
            errorMessage = "Не удалось загрузить модели: \(error.localizedDescription)"
        }
        isLoadingModels = false
    }

    func prepareSegments(_ texts: [String]) {
        segmentStates = texts.enumerated().map { index, text in
            SegmentSynthesisState(
                id: index,
                index: index,
                previewText: String(text.prefix(80))
            )
        }
        totalSegments = segmentStates.count
    }

    func synthesizeAll() async {
        guard !selectedModel.isEmpty else {
            errorMessage = "Пожалуйста, выберите модель"
            return
        }

        isSynthesizing = true
        progress = 0
        errorMessage = nil

        let segments = segmentStates.enumerated().map { index, state in
            (index: state.index, text: state.previewText)
        }

        do {
            let outputDir = AppConstants.tempAudioDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            synthesisTask = Task {
                do {
                    let urls = try await ttsService.synthesizeBatch(
                        segments: segments,
                        modelName: selectedModel,
                        provider: provider,
                        speed: speed,
                        pitch: pitch,
                        emotion: emotion.isEmpty ? nil : emotion,
                        apiURL: apiURL,
                        apiPort: apiPort,
                        outputDirectory: outputDir,
                        progressHandler: { [weak self] prog in
                            guard let self else { return }
                            Task { @MainActor in
                                self.progress = prog
                                let completedCount = Int(prog * Double(segments.count))
                                self.currentSegmentIndex = completedCount
                                for i in 0..<self.segmentStates.count {
                                    if i < completedCount {
                                        self.segmentStates[i].status = .completed
                                    } else if i == completedCount {
                                        self.segmentStates[i].status = .inProgress
                                    }
                                }
                            }
                        }
                    )

                    for (i, url) in urls.enumerated() {
                        if i < segmentStates.count {
                            segmentStates[i].status = .completed
                            segmentStates[i].audioURL = url
                        }
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
                isSynthesizing = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isSynthesizing = false
        }
    }

    func cancelSynthesis() async {
        synthesisTask?.cancel()
        await ttsService.cancel()
        isSynthesizing = false
    }

    func previewSegment(_ index: Int) async {
        // Audio preview handled by AudioPlayerViewModel
    }

    func saveToProject(_ project: VoiceoverProject) {
        project.ttsModelName = selectedModel
        project.ttsSpeed = speed
        project.ttsPitch = pitch
        project.ttsEmotion = emotion.isEmpty ? nil : emotion
        project.updatedAt = Date()
    }
}
