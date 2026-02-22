//
//  SegmentationStrategy.swift
//  BookVoice
//

import Foundation

enum SegmentationStrategy: String, Codable, CaseIterable {
    case bySentence
    case byParagraph
    case byChapter
    case fixedLength

    var displayName: String {
        switch self {
        case .bySentence: "По предложениям"
        case .byParagraph: "По абзацам"
        case .byChapter: "По главам"
        case .fixedLength: "Фиксированная длина"
        }
    }

    var description: String {
        switch self {
        case .bySentence: "Разделить текст по границам предложений"
        case .byParagraph: "Разделить текст по абзацам"
        case .byChapter: "Разделить текст по заголовкам глав"
        case .fixedLength: "Разделить на сегменты фиксированной длины"
        }
    }
}
