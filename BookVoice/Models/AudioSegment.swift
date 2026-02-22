//
//  AudioSegment.swift
//  BookVoice
//

import Foundation
import SwiftData

@Model
final class AudioSegment {
    var id: UUID
    var index: Int
    var textSegmentId: UUID
    var filePath: String?
    var fileBookmark: Data?
    var durationSeconds: Double
    var sampleRate: Int
    var isConverted: Bool
    var isFailed: Bool
    var errorMessage: String?
    var project: VoiceoverProject?

    init(index: Int, textSegmentId: UUID) {
        self.id = UUID()
        self.index = index
        self.textSegmentId = textSegmentId
        self.durationSeconds = 0
        self.sampleRate = AppConstants.defaultSampleRate
        self.isConverted = false
        self.isFailed = false
    }
}
