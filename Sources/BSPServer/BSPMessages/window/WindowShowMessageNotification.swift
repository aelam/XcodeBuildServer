//
//  WindowShowMessageNotification.swift
//
//  Copyright © 2024 Wang Lun.
//

import JSONRPCConnection
import Logger

/// Notification sent by SourceKit-LSP to show a message to the user.
/// This is part of the LSP/BSP protocol for user communication.
public struct WindowShowMessageNotification: ContextualNotificationType, Codable, Sendable {
    public typealias RequiredContext = BSPServerService

    public static func method() -> String {
        "window/showMessage"
    }

    public struct Params: Codable, Sendable {
        /// The message type. See MessageType.
        public let type: MessageType

        /// The actual message.
        public let message: String

        public init(type: MessageType, message: String) {
            self.type = type
            self.message = message
        }
    }

    public let jsonrpc: String
    public let method: String
    public let params: Params

    public init(params: Params) {
        self.jsonrpc = "2.0"
        self.method = Self.method()
        self.params = params
    }

    public init(type: MessageType, message: String) {
        self.init(params: Params(type: type, message: message))
    }

    // Note: handle(handler: MessageHandler) is provided by ContextualNotificationType extension

    // MARK: - ContextualNotificationType Implementation

    /// Handle the show message notification by logging it
    public func handle<Handler: ContextualMessageHandler>(
        contextualHandler: Handler
    ) async throws where Handler.Context == BSPServerService {
        await contextualHandler.withContext { _ in
            logger.info("SourceKit-LSP \(params.type.description) message: \(params.message)")
        }
    }
}

/// Represents the type of message being shown
public enum MessageType: Int, Codable, Sendable {
    /// An error message.
    case error = 1
    /// A warning message.
    case warning = 2
    /// An information message.
    case info = 3
    /// A log message.
    case log = 4

    var description: String {
        switch self {
        case .error: "ERROR"
        case .warning: "WARNING"
        case .info: "INFO"
        case .log: "LOG"
        }
    }
}
