//
//  XcodeBuildLogParser.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation
import Support

/// Parser for Xcode build logs to extract diagnostics and progress information
public struct XcodeBuildLogParser {
    public init() {}

    /// Parse Xcode build output to extract diagnostics
    public func parseDiagnostics(from output: String, for targetId: String) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            if let diagnostic = parseDiagnosticLine(line, targetId: targetId) {
                diagnostics.append(diagnostic)
            }
        }

        return diagnostics
    }

    /// Extract build progress from Xcode output
    public func parseProgress(from output: String) -> Double? {
        let lines = output.components(separatedBy: .newlines)

        for line in lines.suffix(10) { // Check last 10 lines for recent progress
            // Look for compilation progress patterns
            if line.contains("** BUILD SUCCEEDED **") {
                return 1.0
            } else if line.contains("** BUILD FAILED **") {
                return 1.0
            } else if line.contains("Linking") {
                return 0.9
            } else if line.contains("CompileSwift") || line.contains("Compile") {
                return 0.7
            } else if line.contains("Building") {
                return 0.3
            } else if line.contains("Preparing") {
                return 0.1
            }
        }

        return nil
    }

    /// Parse a single line for diagnostic information
    private func parseDiagnosticLine(_ line: String, targetId: String) -> Diagnostic? {
        // Xcode error pattern: /path/to/file.swift:line:column: error: message
        // Xcode warning pattern: /path/to/file.swift:line:column: warning: message

        let pattern = #"^(.+?):(\d+):(\d+):\s+(error|warning|note):\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        let filePath = String(line[Range(match.range(at: 1), in: line)!])
        let lineNumber = Int(String(line[Range(match.range(at: 2), in: line)!])) ?? 1
        let column = Int(String(line[Range(match.range(at: 3), in: line)!])) ?? 1
        let severityString = String(line[Range(match.range(at: 4), in: line)!])
        let message = String(line[Range(match.range(at: 5), in: line)!])

        let severity: DiagnosticSeverity = switch severityString {
        case "error": .error
        case "warning": .warning
        case "note": .information
        default: .information
        }

        let position = Position(line: max(0, lineNumber - 1), character: max(0, column - 1)) // LSP is 0-based
        let range = LSPRange(start: position, end: position)

        return Diagnostic(
            range: range,
            severity: severity,
            code: nil,
            source: "xcodebuild",
            message: message
        )
    }

    /// Extract file paths that have diagnostics
    public func extractAffectedFiles(from output: String) -> Set<String> {
        var files = Set<String>()
        let lines = output.components(separatedBy: .newlines)

        let pattern = #"^(.+?):(\d+):(\d+):\s+(error|warning|note):"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return files
        }

        for line in lines {
            if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let filePath = String(line[Range(match.range(at: 1), in: line)!])
                files.insert(filePath)
            }
        }

        return files
    }
}
