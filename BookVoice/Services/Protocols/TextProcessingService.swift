//
//  TextProcessingService.swift
//  BookVoice
//

import Foundation

protocol TextProcessingService: Sendable {
    /// Load and extract raw text from a file URL (.txt or .epub)
    func loadText(from url: URL) async throws -> String

    /// Segment text according to the given strategy
    func segment(
        text: String,
        strategy: SegmentationStrategy,
        fixedLength: Int
    ) async throws -> [String]

    /// Detect chapters in text (for .byChapter strategy)
    func detectChapters(in text: String) async throws -> [(title: String, range: Range<String.Index>)]
}

enum TextProcessingError: LocalizedError {
    case unsupportedFileType(String)
    case fileReadFailed(String)
    case emptyText
    case segmentationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext): "Unsupported file type: \(ext)"
        case .fileReadFailed(let reason): "Failed to read file: \(reason)"
        case .emptyText: "The text content is empty"
        case .segmentationFailed(let reason): "Segmentation failed: \(reason)"
        }
    }
}
