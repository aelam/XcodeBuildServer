//
//  SourcePathResolver.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// Resolves source paths from Xcode build settings and project configuration
public struct SourcePathResolver: Sendable {
    public init() {}

    /// Extract source paths from build settings
    public func extractSourcePaths(
        from buildSettings: [String: String],
        projectInfo: XcodeProjectInfo
    ) -> [URL] {
        var paths: [URL] = []

        // Add project directory as primary source path
        paths.append(projectInfo.rootURL)

        // Extract paths from common build setting keys
        let sourcePathKeys = [
            "SRCROOT",
            "SOURCE_ROOT",
            "PROJECT_DIR",
            "SWIFT_INCLUDE_PATHS",
            "HEADER_SEARCH_PATHS",
            "USER_HEADER_SEARCH_PATHS"
        ]

        for key in sourcePathKeys {
            if let value = buildSettings[key] {
                let extractedPaths = parsePathValue(value, relativeTo: projectInfo.rootURL)
                paths.append(contentsOf: extractedPaths)
            }
        }

        // Remove duplicates and ensure paths exist
        return Array(Set(paths)).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Get source root directories for BSP
    public func getSourceRoots(
        for targetInfo: XcodeTargetInfo,
        projectInfo: XcodeProjectInfo
    ) -> [URL] {
        var roots: [URL] = []

        // Add project root
        roots.append(projectInfo.rootURL)

        // Add source root if specified in build settings
        if let sourceRoot = targetInfo.buildSettings["SRCROOT"] {
            let sourceRootURL = URL(fileURLWithPath: sourceRoot)
            if !roots.contains(sourceRootURL) {
                roots.append(sourceRootURL)
            }
        }

        // Add built products directory for generated files
        if let builtProductsDir = targetInfo.buildSettings["BUILT_PRODUCTS_DIR"] {
            let builtProductsURL = URL(fileURLWithPath: builtProductsDir)
            if !roots.contains(builtProductsURL) {
                roots.append(builtProductsURL)
            }
        }

        return roots
    }

    /// Get derived sources directory for generated files
    public func getDerivedSourcesDirectory(
        from buildSettings: [String: String]
    ) -> URL? {
        guard let derivedSourcesPath = buildSettings["DERIVED_SOURCES_DIR"] else {
            return nil
        }
        return URL(fileURLWithPath: derivedSourcesPath)
    }

    // MARK: - Private Methods

    private func parsePathValue(_ value: String, relativeTo baseURL: URL) -> [URL] {
        // Handle space-separated and quoted paths
        var paths: [URL] = []
        let components = value.components(separatedBy: " ").filter { !$0.isEmpty }

        for component in components {
            let cleanPath = component.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))

            if cleanPath.hasPrefix("/") {
                // Absolute path
                paths.append(URL(fileURLWithPath: cleanPath))
            } else if !cleanPath.isEmpty {
                // Relative path
                paths.append(baseURL.appendingPathComponent(cleanPath))
            }
        }

        return paths
    }
}
