//
//  LiveTextProcessingService.swift
//  BookVoice
//

import Foundation
import NaturalLanguage

nonisolated final class LiveTextProcessingService: TextProcessingService, Sendable {

    // MARK: - Load Text

    func loadText(from url: URL) async throws -> String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "txt":
            return try loadTXT(from: url)
        case "epub":
            return try await loadEPUB(from: url)
        default:
            throw TextProcessingError.unsupportedFileType(ext)
        }
    }

    // MARK: - Segmentation

    func segment(
        text: String,
        strategy: SegmentationStrategy,
        fixedLength: Int
    ) async throws -> [String] {
        guard !text.isEmpty else {
            throw TextProcessingError.emptyText
        }

        switch strategy {
        case .bySentence:
            return segmentBySentence(text)
        case .byParagraph:
            return segmentByParagraph(text)
        case .byChapter:
            let chapters = try await detectChapters(in: text)
            if chapters.isEmpty {
                return [text]
            }
            return chapters.map { String(text[$0.range]) }
        case .fixedLength:
            return segmentByFixedLength(text, wordCount: fixedLength)
        }
    }

    // MARK: - Chapter Detection

    func detectChapters(in text: String) async throws -> [(title: String, range: Range<String.Index>)] {
        let pattern = #"(?m)^(Chapter|CHAPTER|chapter|Глава|ГЛАВА|глава|Часть|ЧАСТЬ|часть|Part|PART|part)\s+(\d+|[IVXLCDM]+)[\.:\s—–\-]*.*$"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        var chapters: [(title: String, range: Range<String.Index>)] = []

        for (i, match) in matches.enumerated() {
            guard let titleRange = Range(match.range, in: text) else { continue }
            let title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)

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

    // MARK: - Private: TXT

    private func loadTXT(from url: URL) throws -> String {
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Try other encodings
            if let data = try? Data(contentsOf: url) {
                if let decoded = String(data: data, encoding: .windowsCP1251) {
                    return decoded
                }
                if let decoded = String(data: data, encoding: .isoLatin1) {
                    return decoded
                }
            }
            throw TextProcessingError.fileReadFailed(error.localizedDescription)
        }

        guard !text.isEmpty else {
            throw TextProcessingError.emptyText
        }

        return text
    }

    // MARK: - Private: EPUB

    private func loadEPUB(from url: URL) async throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Unzip EPUB
        try unzip(file: url, to: tempDir)

        // Parse container.xml to find .opf path
        let containerURL = tempDir
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")

        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw TextProcessingError.fileReadFailed("Invalid EPUB: META-INF/container.xml not found")
        }

        let containerXML = try String(contentsOf: containerURL, encoding: .utf8)
        guard let opfRelativePath = extractRootfilePath(from: containerXML) else {
            throw TextProcessingError.fileReadFailed("Invalid EPUB: cannot find rootfile in container.xml")
        }

        let opfURL = tempDir.appendingPathComponent(opfRelativePath)
        let opfBaseDir = opfURL.deletingLastPathComponent()

        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw TextProcessingError.fileReadFailed("Invalid EPUB: OPF file not found at \(opfRelativePath)")
        }

        // Parse OPF to get spine order
        let opfXML = try String(contentsOf: opfURL, encoding: .utf8)
        let manifest = parseManifest(from: opfXML)
        let spineIdrefs = parseSpine(from: opfXML)

        // Read XHTML files in spine order and extract text
        var allText: [String] = []

        for idref in spineIdrefs {
            guard let href = manifest[idref] else { continue }
            let xhtmlURL = opfBaseDir.appendingPathComponent(href)
            guard FileManager.default.fileExists(atPath: xhtmlURL.path) else { continue }

            if let xhtmlData = try? Data(contentsOf: xhtmlURL),
               let xhtml = String(data: xhtmlData, encoding: .utf8) {
                let plainText = stripHTML(xhtml)
                let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    allText.append(trimmed)
                }
            }
        }

        let result = allText.joined(separator: "\n\n")

        guard !result.isEmpty else {
            throw TextProcessingError.emptyText
        }

        return result
    }

    private func unzip(file: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", file.path, "-d", destination.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw TextProcessingError.fileReadFailed("Failed to unzip EPUB (exit code \(process.terminationStatus))")
        }
    }

    private func extractRootfilePath(from containerXML: String) -> String? {
        // Extract full-path from <rootfile full-path="..." />
        let pattern = #"full-path\s*=\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: containerXML, range: NSRange(containerXML.startIndex..., in: containerXML)),
              let range = Range(match.range(at: 1), in: containerXML) else {
            return nil
        }
        return String(containerXML[range])
    }

    private func parseManifest(from opfXML: String) -> [String: String] {
        // Extract <item id="..." href="..." /> entries
        var manifest: [String: String] = [:]
        let pattern = #"<item\s[^>]*id\s*=\s*"([^"]+)"[^>]*href\s*=\s*"([^"]+)"[^>]*/?\s*>"#
        let altPattern = #"<item\s[^>]*href\s*=\s*"([^"]+)"[^>]*id\s*=\s*"([^"]+)"[^>]*/?\s*>"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsRange = NSRange(opfXML.startIndex..., in: opfXML)
            for match in regex.matches(in: opfXML, range: nsRange) {
                if let idRange = Range(match.range(at: 1), in: opfXML),
                   let hrefRange = Range(match.range(at: 2), in: opfXML) {
                    let id = String(opfXML[idRange])
                    let href = String(opfXML[hrefRange]).removingPercentEncoding ?? String(opfXML[hrefRange])
                    manifest[id] = href
                }
            }
        }

        // Try alt pattern (href before id)
        if let regex = try? NSRegularExpression(pattern: altPattern) {
            let nsRange = NSRange(opfXML.startIndex..., in: opfXML)
            for match in regex.matches(in: opfXML, range: nsRange) {
                if let hrefRange = Range(match.range(at: 1), in: opfXML),
                   let idRange = Range(match.range(at: 2), in: opfXML) {
                    let id = String(opfXML[idRange])
                    if manifest[id] == nil {
                        let href = String(opfXML[hrefRange]).removingPercentEncoding ?? String(opfXML[hrefRange])
                        manifest[id] = href
                    }
                }
            }
        }

        return manifest
    }

    private func parseSpine(from opfXML: String) -> [String] {
        // Extract <itemref idref="..." /> entries in order
        var idrefs: [String] = []
        let pattern = #"<itemref\s[^>]*idref\s*=\s*"([^"]+)"[^>]*/?\s*>"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsRange = NSRange(opfXML.startIndex..., in: opfXML)
            for match in regex.matches(in: opfXML, range: nsRange) {
                if let idrefRange = Range(match.range(at: 1), in: opfXML) {
                    idrefs.append(String(opfXML[idrefRange]))
                }
            }
        }

        return idrefs
    }

    private func stripHTML(_ html: String) -> String {
        var text = html

        // Remove <head>...</head> section entirely
        if let headRegex = try? NSRegularExpression(pattern: #"<head[^>]*>[\s\S]*?</head>"#, options: .caseInsensitive) {
            text = headRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        // Remove <script> and <style> blocks
        for tag in ["script", "style"] {
            if let regex = try? NSRegularExpression(pattern: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>", options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
        }

        // Replace <br>, </p>, </div>, </h1-6>, </li> with newlines
        if let brRegex = try? NSRegularExpression(pattern: #"<br\s*/?\s*>"#, options: .caseInsensitive) {
            text = brRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n")
        }
        if let blockRegex = try? NSRegularExpression(pattern: #"</(?:p|div|h[1-6]|li|tr|blockquote)>"#, options: .caseInsensitive) {
            text = blockRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n\n")
        }

        // Remove all remaining HTML tags
        if let tagRegex = try? NSRegularExpression(pattern: #"<[^>]+>"#) {
            text = tagRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        // Decode HTML entities
        text = decodeHTMLEntities(text)

        // Normalize whitespace: collapse multiple spaces, normalize newlines
        if let multiSpaceRegex = try? NSRegularExpression(pattern: #"[^\S\n]+"#) {
            text = multiSpaceRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }
        if let multiNewlineRegex = try? NSRegularExpression(pattern: #"\n{3,}"#) {
            text = multiNewlineRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n\n")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#x27;": "'",
            "&#39;": "'",
            "&nbsp;": " ",
            "&mdash;": "\u{2014}",
            "&ndash;": "\u{2013}",
            "&laquo;": "\u{00AB}",
            "&raquo;": "\u{00BB}",
            "&hellip;": "\u{2026}",
            "&copy;": "\u{00A9}",
            "&reg;": "\u{00AE}",
            "&trade;": "\u{2122}",
        ]

        var result = text
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Decode numeric entities like &#123; and &#x1F;
        if let numericRegex = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = numericRegex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[codeRange]),
                   let scalar = Unicode.Scalar(code) {
                    let char = String(Character(scalar))
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: char)
                    }
                }
            }
        }

        if let hexRegex = try? NSRegularExpression(pattern: #"&#x([0-9a-fA-F]+);"#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = hexRegex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[codeRange], radix: 16),
                   let scalar = Unicode.Scalar(code) {
                    let char = String(Character(scalar))
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: char)
                    }
                }
            }
        }

        return result
    }

    // MARK: - Private: Segmentation Strategies

    private func segmentBySentence(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        return sentences
    }

    private func segmentByParagraph(_ text: String) -> [String] {
        var paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Fallback to single newline if no double-newlines found
        if paragraphs.count <= 1 {
            paragraphs = text.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return paragraphs
    }

    private func segmentByFixedLength(_ text: String, wordCount: Int) -> [String] {
        let words = text.split(separator: " ")
        var segments: [String] = []
        var current: [Substring] = []

        for word in words {
            current.append(word)
            if current.count >= wordCount {
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
