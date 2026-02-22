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
        case .bySentence: "By Sentence"
        case .byParagraph: "By Paragraph"
        case .byChapter: "By Chapter"
        case .fixedLength: "Fixed Length"
        }
    }

    var description: String {
        switch self {
        case .bySentence: "Split text at sentence boundaries"
        case .byParagraph: "Split text at paragraph breaks"
        case .byChapter: "Split text at chapter headings"
        case .fixedLength: "Split into segments of fixed word count"
        }
    }
}
