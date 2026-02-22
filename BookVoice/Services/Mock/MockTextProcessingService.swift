//
//  MockTextProcessingService.swift
//  BookVoice
//

import Foundation

nonisolated final class MockTextProcessingService: TextProcessingService, Sendable {
    func loadText(from url: URL) async throws -> String {
        try await Task.sleep(for: .milliseconds(500))

        let ext = url.pathExtension.lowercased()
        guard ext == "txt" || ext == "epub" else {
            throw TextProcessingError.unsupportedFileType(ext)
        }

        // Try reading actual file content, fall back to sample text
        if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
            return text
        }

        return Self.sampleText
    }

    func segment(
        text: String,
        strategy: SegmentationStrategy,
        fixedLength: Int
    ) async throws -> [String] {
        try await Task.sleep(for: .milliseconds(300))

        guard !text.isEmpty else {
            throw TextProcessingError.emptyText
        }

        switch strategy {
        case .bySentence:
            return text.components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

        case .byParagraph:
            return text.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

        case .byChapter:
            let chapters = try await detectChapters(in: text)
            if chapters.isEmpty {
                return [text]
            }
            return chapters.map { String(text[$0.range]) }

        case .fixedLength:
            let words = text.split(separator: " ")
            var segments: [String] = []
            var current: [Substring] = []
            for word in words {
                current.append(word)
                if current.count >= fixedLength {
                    segments.append(current.joined(separator: " "))
                    current = []
                }
            }
            if !current.isEmpty {
                segments.append(current.joined(separator: " "))
            }
            return segments
        }
    }

    func detectChapters(in text: String) async throws -> [(title: String, range: Range<String.Index>)] {
        try await Task.sleep(for: .milliseconds(200))

        var chapters: [(title: String, range: Range<String.Index>)] = []
        let pattern = #"(?m)^(Chapter|CHAPTER|Глава|ГЛАВА)\s+\d+"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        for (i, match) in matches.enumerated() {
            guard let titleRange = Range(match.range, in: text) else { continue }
            let title = String(text[titleRange])

            let contentStart = titleRange.lowerBound
            let contentEnd: String.Index
            if i + 1 < matches.count, let nextRange = Range(matches[i + 1].range, in: text) {
                contentEnd = nextRange.lowerBound
            } else {
                contentEnd = text.endIndex
            }

            chapters.append((title: title, range: contentStart..<contentEnd))
        }

        return chapters
    }

    private static let sampleText = """
    Chapter 1: The Beginning

    It was a bright cold day in April, and the clocks were striking thirteen. \
    Winston Smith, his chin nuzzled into his breast in an effort to escape the \
    vile wind, slipped quickly through the glass doors of Victory Mansions, \
    though not quickly enough to prevent a swirl of gritty dust from entering along with him.

    The hallway smelt of boiled cabbage and old rag mats. At one end of it a \
    coloured poster, too large for indoor display, had been tacked to the wall. \
    It depicted simply an enormous face, more than a metre wide: the face of a \
    man of about forty-five, with a heavy black moustache and ruggedly handsome features.

    Chapter 2: The Discovery

    Behind Winston's back the voice from the telescreen was still babbling away \
    about pig-iron and the overfulfilment of the Ninth Three-Year Plan. The \
    telescreen received and transmitted simultaneously. Any sound that Winston \
    made, above the level of a very low whisper, would be picked up by it.

    There was of course no way of knowing whether you were being watched at any \
    given moment. How often, or on what system, the Thought Police plugged in on \
    any individual wire was guesswork.
    """
}
