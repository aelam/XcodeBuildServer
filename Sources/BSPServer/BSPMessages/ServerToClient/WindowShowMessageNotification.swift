//
//  WindowShowMessageNotification.swift
//
//  Copyright © 2024 Wang Lun.
//

import JSONRPCConnection
import Logger

/// Parameters for window/showMessage notification
public struct WindowShowMessageParams: Codable, Sendable {
    public static let method = "window/showMessage"
    /// The message type. See MessageType.
    public let type: LogMessageType

    /// The actual message.
    public let message: String

    public init(type: LogMessageType, message: String) {
        self.type = type
        self.message = message
    }
}

/// Represents the type of message being shown
public enum LogMessageType: Int, Codable, Sendable {
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
