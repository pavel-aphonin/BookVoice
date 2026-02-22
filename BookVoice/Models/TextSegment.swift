//
//  TextSegment.swift
//  BookVoice
//

import Foundation
import SwiftData

@Model
final class TextSegment {
    var id: UUID
    var index: Int
    var text: String
    var characterCount: Int
    var estimatedDurationSeconds: Double
    var project: VoiceoverProject?

    init(index: Int, text: String) {
        self.id = UUID()
        self.index = index
        self.text = text
        self.characterCount = text.count
        let wordCount = text.split(separator: " ").count
        self.estimatedDurationSeconds = Double(wordCount) / 2.5
    }
}
