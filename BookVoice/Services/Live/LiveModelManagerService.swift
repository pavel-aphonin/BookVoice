//
//  LiveModelManagerService.swift
//  BookVoice
//
//  Manages TTS and RVC model files: download, validate, list, delete.
//

import Foundation

nonisolated final class LiveModelManagerService: ModelManagerService, Sendable {

    var defaultModelDirectory: URL {
        AppConstants.modelsDirectory
    }

    // MARK: - Download

    func downloadModel(
        from url: URL,
        to destinationDirectory: URL,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let destination = destinationDirectory.appendingPathComponent(url.lastPathComponent)

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        let request = URLRequest(url: url)
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ModelManagerError.downloadFailed("Server returned error for \(url.lastPathComponent)")
        }

        let expectedLength = httpResponse.expectedContentLength
        var receivedLength: Int64 = 0

        guard let outputStream = OutputStream(url: destination, append: false) else {
            throw ModelManagerError.downloadFailed("Cannot create output file")
        }
        outputStream.open()
        defer { outputStream.close() }

        // Read in chunks for progress reporting
        var buffer: [UInt8] = []
        let chunkSize = 65536

        for try await byte in asyncBytes {
            buffer.append(byte)

            if buffer.count >= chunkSize {
                let written = buffer.withUnsafeBufferPointer { ptr in
                    outputStream.write(ptr.baseAddress!, maxLength: ptr.count)
                }
                guard written > 0 else {
                    throw ModelManagerError.downloadFailed("Failed to write to file")
                }
                receivedLength += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)

                if expectedLength > 0 {
                    progressHandler(Double(receivedLength) / Double(expectedLength))
                }
            }
        }

        // Write remaining bytes
        if !buffer.isEmpty {
            let written = buffer.withUnsafeBufferPointer { ptr in
                outputStream.write(ptr.baseAddress!, maxLength: ptr.count)
            }
            guard written > 0 else {
                throw ModelManagerError.downloadFailed("Failed to write remaining data")
            }
            receivedLength += Int64(buffer.count)
        }

        progressHandler(1.0)
        return destination
    }

    // MARK: - Validate

    func validateModelPath(_ path: String) async throws -> Bool {
        guard !path.isEmpty else { return false }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return false }

        // Check valid extension
        let validExtensions: Set<String> = ["pt", "pth", "bin", "onnx"]
        let ext = (path as NSString).pathExtension.lowercased()
        guard validExtensions.contains(ext) else { return false }

        // Check non-zero size
        do {
            let attrs = try fileManager.attributesOfItem(atPath: path)
            let size = attrs[.size] as? Int64 ?? 0
            return size > 0
        } catch {
            return false
        }
    }

    // MARK: - List Models

    func listModels(in directory: URL) async throws -> [ModelInfo] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw ModelManagerError.directoryNotFound(directory.path)
        }

        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]
            )
        } catch {
            throw ModelManagerError.directoryNotFound(error.localizedDescription)
        }

        let modelExtensions: Set<String> = ["pt", "pth", "bin", "onnx"]

        var models: [ModelInfo] = []

        for fileURL in contents {
            let ext = fileURL.pathExtension.lowercased()
            guard modelExtensions.contains(ext) else { continue }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .creationDateKey])
                let size = Int64(resourceValues.fileSize ?? 0)
                let date = resourceValues.contentModificationDate ?? resourceValues.creationDate ?? Date()

                models.append(ModelInfo(
                    name: fileURL.lastPathComponent,
                    size: size,
                    date: date,
                    path: fileURL
                ))
            } catch {
                // Skip files with unreadable attributes
                continue
            }
        }

        // Sort by date descending (newest first)
        models.sort { $0.date > $1.date }

        return models
    }

    // MARK: - Delete

    func deleteModel(at path: URL) async throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw ModelManagerError.deleteFailed("File not found: \(path.lastPathComponent)")
        }

        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            throw ModelManagerError.deleteFailed(error.localizedDescription)
        }
    }
}

