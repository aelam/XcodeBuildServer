//
//  SourceFileModels.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// Represents a discovered source file
public struct DiscoveredSourceFile: Sendable {
    public let url: URL
    public let language: String
    public let sourceType: SourceFileType
    public let isGenerated: Bool
    public let targetName: String

    public init(
        url: URL,
        language: String,
        sourceType: SourceFileType,
        isGenerated: Bool,
        targetName: String
    ) {
        self.url = url
        self.language = language
        self.sourceType = sourceType
        self.isGenerated = isGenerated
        self.targetName = targetName
    }
}

/// Types of source files
public enum SourceFileType: String, Sendable, CaseIterable {
    case source
    case header
    case resource
    case documentation

    public var description: String {
        switch self {
        case .source:
            "Source File"
        case .header:
            "Header File"
        case .resource:
            "Resource File"
        case .documentation:
            "Documentation File"
        }
    }
}

/// Result of converting a DiscoveredSourceFile to BSP format
public struct SourceItemConversionResult: Sendable {
    public let uri: String
    public let kind: Int
    public let generated: Bool
    public let dataKind: String?
    public let data: [String: String]?

    public init(uri: String, kind: Int, generated: Bool, dataKind: String?, data: [String: String]?) {
        self.uri = uri
        self.kind = kind
        self.generated = generated
        self.dataKind = dataKind
        self.data = data
    }
}

/// Configuration for source file scanning
public struct SourceScanConfiguration: Sendable {
    public let skipHiddenFiles: Bool
    public let skipBuildDirectories: Bool
    public let skipPackageDirectories: Bool
    public let maxDepth: Int?
    public let allowedExtensions: Set<String>?

    public init(
        skipHiddenFiles: Bool = true,
        skipBuildDirectories: Bool = true,
        skipPackageDirectories: Bool = true,
        maxDepth: Int? = nil,
        allowedExtensions: Set<String>? = nil
    ) {
        self.skipHiddenFiles = skipHiddenFiles
        self.skipBuildDirectories = skipBuildDirectories
        self.skipPackageDirectories = skipPackageDirectories
        self.maxDepth = maxDepth
        self.allowedExtensions = allowedExtensions
    }

    public static let `default` = SourceScanConfiguration()
}
