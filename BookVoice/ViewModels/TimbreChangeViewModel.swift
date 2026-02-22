//
//  TimbreChangeViewModel.swift
//  BookVoice
//

import Foundation
import AppKit
import UniformTypeIdentifiers

@Observable
final class TimbreChangeViewModel {
    var isEnabled: Bool
    var modelPath: String
    var indexRate: Double
    var filterRadius: Int
    var protectVoiceless: Double
    var voiceSampleURL: URL?

    var availableModels: [String] = []
    var isConverting = false
    var progress: Double = 0
    var errorMessage: String?
    var isLoadingModels = false

    var isValid: Bool {
        !isEnabled || !modelPath.isEmpty
    }

    private let rvcService: any RVCService
    private let modelManager: any ModelManagerService
    private var conversionTask: Task<Void, Never>?

    init(project: VoiceoverProject, rvcService: any RVCService, modelManager: any ModelManagerService) {
        self.rvcService = rvcService
        self.modelManager = modelManager
        self.isEnabled = project.rvcEnabled
        self.modelPath = project.rvcModelPath ?? ""
        self.indexRate = project.rvcIndexRate
        self.filterRadius = project.rvcFilterRadius
        self.protectVoiceless = project.rvcProtectVoiceless
    }

    func loadModels() async {
        isLoadingModels = true
        do {
            availableModels = try await rvcService.availableModels(
                at: modelManager.defaultModelDirectory
            )
            if modelPath.isEmpty, let first = availableModels.first {
                modelPath = first
            }
        } catch {
            errorMessage = "Failed to load RVC models: \(error.localizedDescription)"
        }
        isLoadingModels = false
    }

    func browseModel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.data]
        panel.message = "Select an RVC model file (.pth)"

        if panel.runModal() == .OK, let url = panel.url {
            modelPath = url.path
        }
    }

    func browseVoiceSample() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        panel.message = "Select a voice sample audio file"

        if panel.runModal() == .OK, let url = panel.url {
            voiceSampleURL = url
        }
    }

    func convertAll(inputURLs: [URL]) async {
        guard isEnabled, !modelPath.isEmpty else { return }

        isConverting = true
        progress = 0
        errorMessage = nil

        do {
            let outputDir = AppConstants.tempAudioDirectory
                .appendingPathComponent("rvc_\(UUID().uuidString)")

            conversionTask = Task {
                do {
                    _ = try await rvcService.convertBatch(
                        inputURLs: inputURLs,
                        outputDirectory: outputDir,
                        modelPath: modelPath,
                        indexRate: indexRate,
                        filterRadius: filterRadius,
                        protectVoiceless: protectVoiceless,
                        progressHandler: { [weak self] prog in
                            Task { @MainActor in
                                self?.progress = prog
                            }
                        }
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
                isConverting = false
            }
        }
    }

    func cancelConversion() async {
        conversionTask?.cancel()
        await rvcService.cancel()
        isConverting = false
    }

    func saveToProject(_ project: VoiceoverProject) {
        project.rvcEnabled = isEnabled
        project.rvcModelPath = modelPath.isEmpty ? nil : modelPath
        project.rvcIndexRate = indexRate
        project.rvcFilterRadius = filterRadius
        project.rvcProtectVoiceless = protectVoiceless
        project.updatedAt = Date()
    }
}
