//
//  Logger.swift
//
//  Copyright © 2024 Wang Lun.
//

@preconcurrency import OSLog
import Foundation

nonisolated(unsafe) let privacy: OSLogPrivacy = .public

final class FileLogger: @unchecked Sendable {
    private let fileURL: URL
    private let osLogger: Logger
    private let queue = DispatchQueue(label: "fileLogger", qos: .utility)

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.osLogger = Logger(subsystem: "XcodeBuildServer", category: "main")

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    private func writeToFile(_ message: String, level: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timestamp = formatter.string(from: Date())
            let logEntry = "[\(timestamp)] [\(level)] \(message)\n"

            if let data = logEntry.data(using: .utf8) {
                if let fileHandle = try? FileHandle(forWritingTo: self.fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } else {
                    try? data.write(to: self.fileURL)
                }
            }
        }
    }

    func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        writeToFile(message, level: "INFO")
    }

    func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .public)")
        writeToFile(message, level: "DEBUG")
    }

    func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        writeToFile(message, level: "ERROR")
    }

    func warning(_ message: String) {
        osLogger.warning("\(message, privacy: .public)")
        writeToFile(message, level: "WARNING")
    }
}

let logger = FileLogger(
    fileURL: URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Desktop")
        .appendingPathComponent("Xcodebuildserver.log")
)
