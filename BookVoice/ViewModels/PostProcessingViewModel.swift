//
//  PostProcessingViewModel.swift
//  BookVoice
//

import Foundation
import AppKit
import UniformTypeIdentifiers

@Observable
final class PostProcessingViewModel {
    var outputFormat: AudioFormat
    var metadataTitle: String
    var metadataArtist: String
    var metadataAlbum: String
    var metadataYear: String
    var coverImageData: Data?

    var isMerging = false
    var isExporting = false
    var progress: Double = 0
    var errorMessage: String?
    var outputURL: URL?

    var canExport: Bool {
        !metadataTitle.isEmpty
    }

    private let audioEngine: any AudioEngineService
    private let notificationService: any NotificationService

    init(project: VoiceoverProject, audioEngine: any AudioEngineService, notificationService: any NotificationService) {
        self.audioEngine = audioEngine
        self.notificationService = notificationService
        self.outputFormat = project.outputFormat
        self.metadataTitle = project.metadataTitle ?? project.title
        self.metadataArtist = project.metadataArtist ?? project.author
        self.metadataAlbum = project.metadataAlbum ?? ""
        self.metadataYear = project.metadataYear ?? ""
        self.coverImageData = project.coverImageData
    }

    func selectCoverImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = "Выберите обложку"

        if panel.runModal() == .OK, let url = panel.url {
            coverImageData = try? Data(contentsOf: url)
        }
    }

    func export(audioFiles: [URL]) async {
        guard canExport else { return }

        guard !audioFiles.isEmpty else {
            errorMessage = "Нет аудиофайлов для экспорта. Сначала выполните озвучку."
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.audio]
        savePanel.nameFieldStringValue = "\(metadataTitle).\(outputFormat.fileExtension)"

        guard savePanel.runModal() == .OK, let saveURL = savePanel.url else { return }

        isExporting = true
        progress = 0
        errorMessage = nil

        do {
            let result = try await audioEngine.concatenate(
                files: audioFiles,
                outputURL: saveURL,
                format: outputFormat,
                progressHandler: { [weak self] prog in
                    guard let self else { return }
                    Task { @MainActor in
                        self.progress = prog
                    }
                }
            )

            try await audioEngine.writeMetadata(
                to: result,
                title: metadataTitle,
                artist: metadataArtist.isEmpty ? nil : metadataArtist,
                album: metadataAlbum.isEmpty ? nil : metadataAlbum,
                year: metadataYear.isEmpty ? nil : metadataYear,
                coverImage: coverImageData
            )

            outputURL = result
            await notificationService.send(
                title: "Экспорт завершён",
                body: "\(metadataTitle) экспортирован"
            )
        } catch {
            errorMessage = "Ошибка экспорта: \(error.localizedDescription)"
            await notificationService.send(
                title: "Ошибка экспорта",
                body: error.localizedDescription
            )
        }

        isExporting = false
    }

    func revealInFinder() {
        guard let url = outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func saveToProject(_ project: VoiceoverProject) {
        project.outputFormat = outputFormat
        project.metadataTitle = metadataTitle
        project.metadataArtist = metadataArtist
        project.metadataAlbum = metadataAlbum
        project.metadataYear = metadataYear
        project.coverImageData = coverImageData
        project.updatedAt = Date()
    }
}
