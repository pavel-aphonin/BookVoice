//
//  Logger.swift
//  BookVoice
//

import Foundation
import os

nonisolated final class AppLogger: LoggingService, Sendable {
    static let shared = AppLogger()

    private let osLogger = os.Logger(subsystem: "com.BookVoice.BookVoice", category: "app")

    func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent

        switch level {
        case .debug:
            osLogger.debug("[\(fileName):\(line)] \(message)")
        case .info:
            osLogger.info("[\(fileName):\(line)] \(message)")
        case .warning:
            osLogger.warning("[\(fileName):\(line)] \(message)")
        case .error:
            osLogger.error("[\(fileName):\(line)] \(message)")
        }

        writeToFile(message: message, level: level, file: fileName, function: function, line: line)
    }

    private func writeToFile(message: String, level: LogLevel, file: String, function: String, line: Int) {
        let logDir = AppConstants.logsDirectory
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let logFile = logDir.appendingPathComponent("\(dateFormatter.string(from: Date())).log")

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = timeFormatter.string(from: Date())

        let logLine = "[\(timestamp)] [\(level.rawValue.uppercased())] [\(file):\(line)] \(message)\n"

        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }
}
