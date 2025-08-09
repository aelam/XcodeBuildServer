//
//  XcodeSchemeError.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// Errors that can occur during scheme parsing
public enum XcodeSchemeError: Error, CustomStringConvertible, Equatable {
    case invalidConfig(String)
    case schemeNotFound(String)
    case dataParsingError(String)

    public var description: String {
        switch self {
        case let .invalidConfig(reason):
            "Invalid configuration: \(reason)"
        case let .schemeNotFound(scheme):
            "Scheme '\(scheme)' not found in project"
        case let .dataParsingError(message):
            "Data parsing error: \(message)"
        }
    }
}
