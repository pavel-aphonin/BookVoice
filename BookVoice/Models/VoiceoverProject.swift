//
//  VoiceoverProject.swift
//  BookVoice
//

import Foundation
import SwiftData

@Model
final class VoiceoverProject {
    var id: UUID
    var title: String
    var author: String
    var coverImageData: Data?
    var status: ProjectStatus
    var createdAt: Date
    var updatedAt: Date

    // Step 1: Model settings
    var apiURL: String
    var apiPort: Int
    var ttsProvider: TTSProvider
    var systemPrompt: String

    // Step 2: Text
    var sourceFileName: String?
    var sourceFileBookmark: Data?
    var rawText: String?
    var segmentationStrategy: SegmentationStrategy
    var fixedSegmentLength: Int

    @Relationship(deleteRule: .cascade, inverse: \TextSegment.project)
    var textSegments: [TextSegment]

    // Step 3: Text Preprocessing (LLM)
    var llmProvider: LLMProvider?
    var llmModel: String?
    var llmCustomPrompt: String?
    var llmSkipped: Bool?
    var preprocessedSegmentsJSON: Data?
    var preprocessingOptionsJSON: Data?

    // Step 4: Voiceover
    var ttsModelName: String?
    var ttsSpeed: Double
    var ttsPitch: Double
    var ttsEmotion: String?
    // Расширенные параметры (Qwen)
    var ttsSpeaker: String?
    var ttsLanguage: String?
    var ttsTemperature: Double?
    var ttsTopK: Int?
    var ttsTopP: Double?
    var ttsRepetitionPenalty: Double?
    var ttsDoSample: Bool?
    var ttsMaxNewTokens: Int?
    // Voice cloning reference (Qwen Base models)
    var ttsReferenceAudioBookmark: Data?
    var ttsReferenceText: String?
    var ttsXVectorOnlyMode: Bool?
    // Subtalker parameters (voice cloning)
    var ttsSubtalkerTemperature: Double?
    var ttsSubtalkerTopK: Int?
    var ttsSubtalkerTopP: Double?
    var ttsSubtalkerDoSample: Bool?

    @Relationship(deleteRule: .cascade, inverse: \AudioSegment.project)
    var audioSegments: [AudioSegment]

    // Step 5: RVC
    var rvcEnabled: Bool
    var rvcModelPath: String?
    var rvcModelPathBookmark: Data?
    var rvcIndexRate: Double
    var rvcFilterRadius: Int
    var rvcProtectVoiceless: Double
    var voiceSampleBookmark: Data?

    // Step 6: Export
    var outputFormat: AudioFormat
    var outputDirectoryPath: String?
    var outputDirectoryBookmark: Data?
    var metadataTitle: String?
    var metadataArtist: String?
    var metadataAlbum: String?
    var metadataYear: String?

    // Progress tracking
    var currentStep: Int
    var synthesisProgress: Double
    var conversionProgress: Double
    var exportProgress: Double
    var errorMessage: String?

    init(title: String = "Untitled Project") {
        self.id = UUID()
        self.title = title
        self.author = ""
        self.status = .draft
        self.createdAt = Date()
        self.updatedAt = Date()

        self.apiURL = AppConstants.defaultAPIURL
        self.apiPort = AppConstants.defaultAPIPort
        self.ttsProvider = .silero
        self.systemPrompt = ""

        self.segmentationStrategy = .byParagraph
        self.fixedSegmentLength = AppConstants.defaultFixedSegmentLength
        self.textSegments = []

        self.ttsSpeed = AppConstants.defaultSpeed
        self.ttsPitch = AppConstants.defaultPitch
        self.ttsTemperature = -1   // -1 = авто
        self.ttsTopK = -1
        self.ttsTopP = -1
        self.ttsRepetitionPenalty = -1
        self.ttsDoSample = true
        self.ttsMaxNewTokens = nil
        self.ttsReferenceAudioBookmark = nil
        self.ttsReferenceText = nil
        self.ttsXVectorOnlyMode = false
        self.ttsSubtalkerTemperature = nil
        self.ttsSubtalkerTopK = nil
        self.ttsSubtalkerTopP = nil
        self.ttsSubtalkerDoSample = nil
        self.audioSegments = []

        self.rvcEnabled = false
        self.rvcIndexRate = AppConstants.defaultRVCIndexRate
        self.rvcFilterRadius = AppConstants.defaultRVCFilterRadius
        self.rvcProtectVoiceless = AppConstants.defaultRVCProtectVoiceless

        self.outputFormat = .mp3
        self.currentStep = 1
        self.synthesisProgress = 0
        self.conversionProgress = 0
        self.exportProgress = 0
    }
}
