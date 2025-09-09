import Foundation

public struct Diagnostic: Codable, Sendable {
    public let range: LSPRange
    public let severity: DiagnosticSeverity?
    public let code: String?
    public let source: String?
    public let message: String
    public let relatedInformation: [DiagnosticRelatedInformation]?

    public init(
        range: LSPRange,
        severity: DiagnosticSeverity? = nil,
        code: String? = nil,
        source: String? = nil,
        message: String,
        relatedInformation: [DiagnosticRelatedInformation]? = nil
    ) {
        self.range = range
        self.severity = severity
        self.code = code
        self.source = source
        self.message = message
        self.relatedInformation = relatedInformation
    }
}

public struct LSPRange: Codable, Sendable {
    public let start: Position
    public let end: Position

    public init(start: Position, end: Position) {
        self.start = start
        self.end = end
    }
}

public struct Position: Codable, Sendable {
    public let line: Int
    public let character: Int

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}

public enum DiagnosticSeverity: Int, Codable, Sendable {
    case error = 1
    case warning = 2
    case information = 3
    case hint = 4
}

public struct DiagnosticRelatedInformation: Codable, Sendable {
    public let location: Location
    public let message: String

    public init(location: Location, message: String) {
        self.location = location
        self.message = message
    }
}

public struct Location: Codable, Sendable {
    public let uri: String
    public let range: LSPRange

    public init(uri: String, range: LSPRange) {
        self.uri = uri
        self.range = range
    }
}
