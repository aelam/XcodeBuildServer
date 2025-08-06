//
//  Error.swift
//
//  Copyright © 2024 Wang Lun.
//

public struct ErrorCode: RawRepresentable, Codable, Hashable, Sendable {
    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    // MARK: JSON RPC

    public static let parseError: ErrorCode = .init(rawValue: -32700)
    public static let invalidRequest: ErrorCode = .init(rawValue: -32600)
    public static let methodNotFound: ErrorCode = .init(rawValue: -32601)
    public static let invalidParams: ErrorCode = .init(rawValue: -32602)
    public static let internalError: ErrorCode = .init(rawValue: -32603)

    /// This is the start range of JSON-RPC reserved error codes.
    /// It doesn't denote a real error code. No LSP error codes should
    /// be defined between the start and end range. For backwards
    /// compatibility the `ServerNotInitialized` and the `UnknownErrorCode`
    /// are left in the range.
    public static let jsonrpcReservedErrorRangeStart = ErrorCode(rawValue: -32099)
    public static let serverErrorStart: ErrorCode = jsonrpcReservedErrorRangeStart

    /// Error code indicating that a server received a notification or
    /// request before the server has received the `initialize` request.
    public static let serverNotInitialized = ErrorCode(rawValue: -32002)
    public static let unknownErrorCode = ErrorCode(rawValue: -32001)

    /// This is the end range of JSON-RPC reserved error codes.
    /// It doesn't denote a real error code.
    public static let jsonrpcReservedErrorRangeEnd = ErrorCode(rawValue: -32000)
    /// Deprecated, use jsonrpcReservedErrorRangeEnd
    public static let serverErrorEnd = jsonrpcReservedErrorRangeEnd

    /// A request failed but it was syntactically correct, e.g the
    /// method name was known and the parameters were valid. The error
    /// message should contain human readable information about why
    /// the request failed.
    public static let requestFailed = ErrorCode(rawValue: -32803)

    /// The server cancelled the request. This error code should
    /// only be used for requests that explicitly support being
    /// server cancellable.
    public static let serverCancelled = ErrorCode(rawValue: -32802)

    /// The server detected that the content of a document got
    /// modified outside normal conditions. A server should
    /// NOT send this error code if it detects a content change
    /// in it unprocessed messages. The result even computed
    /// on an older state might still be useful for the client.
    ///
    /// If a client decides that a result is not of any use anymore
    /// the client should cancel the request.
    public static let contentModified = ErrorCode(rawValue: -32801)

    /// The client has canceled a request and a server as detected
    /// the cancel.
    public static let cancelled: ErrorCode = .init(rawValue: -32800)
}

/// An error during message decoding.
public struct MessageDecodingError: Error, Hashable {
    /// The error code.
    public var code: ErrorCode

    /// A free-form description of the error.
    public var message: String

    /// If it was possible to recover the request id, it is stored here. This can be used e.g. to reply with a
    /// `ResponseError` to invalid requests.
    public var id: RequestID?

    @frozen
    public enum MessageKind: Sendable {
        case request
        case response
        case notification
        case unknown
    }

    /// What kind of message was being decoded, or `.unknown`.
    public var messageKind: MessageKind

    public init(code: ErrorCode, message: String, id: RequestID? = nil, messageKind: MessageKind = .unknown) {
        self.code = code
        self.message = message
        self.id = id
        self.messageKind = messageKind
    }
}

public extension MessageDecodingError {
    static func methodNotFound(
        _ method: String,
        id: RequestID? = nil,
        messageKind: MessageKind = .unknown
    ) -> MessageDecodingError {
        MessageDecodingError(
            code: .methodNotFound,
            message: "method not found: \(method)",
            id: id,
            messageKind: messageKind
        )
    }

    static func invalidRequest(
        _ reason: String,
        id: RequestID? = nil,
        messageKind: MessageKind = .unknown
    ) -> MessageDecodingError {
        MessageDecodingError(code: .invalidRequest, message: reason, id: id, messageKind: messageKind)
    }

    static func invalidParams(
        _ reason: String,
        id: RequestID? = nil,
        messageKind: MessageKind = .unknown
    ) -> MessageDecodingError {
        MessageDecodingError(code: .invalidParams, message: reason, id: id, messageKind: messageKind)
    }

    static func parseError(
        _ reason: String,
        id: RequestID? = nil,
        messageKind: MessageKind = .unknown
    ) -> MessageDecodingError {
        MessageDecodingError(code: .parseError, message: reason, id: id, messageKind: messageKind)
    }
}

public struct ResponseError: Error, Codable, Hashable {
    public var code: ErrorCode
    public var message: String

    public init(code: ErrorCode, message: String) {
        self.code = code
        self.message = message
    }
}

public extension ResponseError {
    /// Converts a `MessageDecodingError` to a `ResponseError`.
    init(_ decodingError: MessageDecodingError) {
        self.init(code: decodingError.code, message: decodingError.message)
    }
}