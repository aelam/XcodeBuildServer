//
//  XcodeIndexPathResolver.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public struct XcodeIndexPaths: Sendable {
    public let derivedDataPath: URL
    public let indexStoreURL: URL
    public let indexDatabaseURL: URL

    public init(derivedDataPath: URL, indexStoreURL: URL, indexDatabaseURL: URL) {
        self.derivedDataPath = derivedDataPath
        self.indexStoreURL = indexStoreURL
        self.indexDatabaseURL = indexDatabaseURL
    }
}

public enum XcodeIndexPathResolver {
    /// Resolve index paths from build settings JSON data
    public static func resolveIndexPaths(from buildSettingsData: Data) throws -> XcodeIndexPaths {
        let buildSettings = try JSONSerialization.jsonObject(with: buildSettingsData) as? [String: Any]
        let derivedDataPath = extractDerivedDataPath(from: buildSettings)

        let indexStoreURL = derivedDataPath.appendingPathComponent("Index/DataStore")
        let indexDatabaseURL = derivedDataPath.appendingPathComponent("Index/DB")

        return XcodeIndexPaths(
            derivedDataPath: derivedDataPath,
            indexStoreURL: indexStoreURL,
            indexDatabaseURL: indexDatabaseURL
        )
    }

    /// Extract derived data path from build settings dictionary
    public static func extractDerivedDataPath(from buildSettings: [String: Any]?) -> URL {
        // Try to extract from common build setting keys
        if let objRoot = buildSettings?["OBJROOT"] as? String {
            let url = URL(fileURLWithPath: objRoot)
            return url.deletingLastPathComponent().deletingLastPathComponent()
        }

        if let builtProductsDir = buildSettings?["BUILT_PRODUCTS_DIR"] as? String {
            let url = URL(fileURLWithPath: builtProductsDir)
            return url.deletingLastPathComponent().deletingLastPathComponent()
        }

        // Fallback to default derived data location
        return defaultDerivedDataPath()
    }

    /// Get default derived data path when build settings are not available
    public static func defaultDerivedDataPath() -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Developer")
            .appendingPathComponent("Xcode")
            .appendingPathComponent("DerivedData")
    }

    /// Create index paths with custom derived data path
    public static func createIndexPaths(derivedDataPath: URL) -> XcodeIndexPaths {
        let indexStoreURL = derivedDataPath.appendingPathComponent("Index/DataStore")
        let indexDatabaseURL = derivedDataPath.appendingPathComponent("Index/DB")

        return XcodeIndexPaths(
            derivedDataPath: derivedDataPath,
            indexStoreURL: indexStoreURL,
            indexDatabaseURL: indexDatabaseURL
        )
    }
}
