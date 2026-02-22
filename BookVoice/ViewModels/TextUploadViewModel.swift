//
//  TextUploadViewModel.swift
//  BookVoice
//

import Foundation

@Observable
final class TextUploadViewModel {
    var rawText: String = ""
    var fileName: String?
    var isLoading = false
    var errorMessage: String?
    var strategy: SegmentationStrategy = .byParagraph
    var fixedLength: Int = AppConstants.defaultFixedSegmentLength
    var previewSegments: [String] = []
    var totalSegmentCount: Int = 0

    var isValid: Bool {
        !rawText.isEmpty && totalSegmentCount > 0
    }

    var characterCount: Int { rawText.count }
    var wordCount: Int { rawText.split(separator: " ").count }

    private let textService: any TextProcessingService

    init(project: VoiceoverProject, textService: any TextProcessingService) {
        self.textService = textService
        self.rawText = project.rawText ?? ""
        self.fileName = project.sourceFileName
        self.strategy = project.segmentationStrategy
        self.fixedLength = project.fixedSegmentLength

        if !rawText.isEmpty {
            Task { await segmentText() }
        }
    }

    func loadFile(from url: URL) async {
        isLoading = true
        errorMessage = nil

        do {
            let shouldAccess = url.startAccessingSecurityScopedResource()
            defer { if shouldAccess { url.stopAccessingSecurityScopedResource() } }

            rawText = try await textService.loadText(from: url)
            fileName = url.lastPathComponent
            await segmentText()
        } catch {
            errorMessage = "Failed to load file: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func segmentText() async {
        guard !rawText.isEmpty else { return }
        errorMessage = nil

        do {
            let segments = try await textService.segment(
                text: rawText,
                strategy: strategy,
                fixedLength: fixedLength
            )
            totalSegmentCount = segments.count
            previewSegments = Array(segments.prefix(AppConstants.maxPreviewSegments))
        } catch {
            errorMessage = "Segmentation failed: \(error.localizedDescription)"
        }
    }

    func saveToProject(_ project: VoiceoverProject) {
        project.rawText = rawText
        project.sourceFileName = fileName
        project.segmentationStrategy = strategy
        project.fixedSegmentLength = fixedLength
        project.status = .textLoaded
        project.updatedAt = Date()
    }

    func allSegments() async -> [String] {
        guard !rawText.isEmpty else { return [] }
        do {
            return try await textService.segment(
                text: rawText,
                strategy: strategy,
                fixedLength: fixedLength
            )
        } catch {
            return []
        }
    }
}
