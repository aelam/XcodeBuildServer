//
//  XcodeBSPConfigurationLoader.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeProjectManagement

/// BSP Configuration for Xcode projects
/// 
/// Supports conditional loading to reduce project loading overhead:
/// - `workspace`: Optional workspace path
/// - `project`: Optional project path  
/// - `scheme`: Optional single scheme name
/// - `schemes`: Optional array of scheme names
/// - `configuration`: Optional build configuration (defaults to "Debug")
///
/// When schemes are specified, only those schemes and their targets will be loaded,
/// significantly reducing initialization time for large projects.
///
/// Example .bsp/xcode.json:
/// ```json
/// {
///   "project": "MyApp.xcodeproj",
///   "schemes": ["MyApp", "MyAppTests"],
///   "configuration": "Debug"
/// }
/// ```
public struct XcodeBSPConfiguration: Codable, Sendable {
    public let workspace: String?
    public let project: String?
    public let scheme: String?
    public let schemes: [String]?
    public let configuration: String?

    public static let defaultConfiguration = "Debug"

    public init(workspace: String? = nil, project: String? = nil, scheme: String? = nil, schemes: [String]? = nil, configuration: String? = nil) {
        self.workspace = workspace
        self.project = project
        self.scheme = scheme
        self.schemes = schemes
        self.configuration = configuration
    }
    
    /// Get all scheme names to load (combining single scheme and schemes array)
    public var allSchemes: [String] {
        var result: [String] = []
        if let scheme = scheme {
            result.append(scheme)
        }
        if let schemes = schemes {
            result.append(contentsOf: schemes)
        }
        return Array(Set(result)) // Remove duplicates
    }

    // Convert to XcodeProjectReference for project management
    public var projectReference: XcodeProjectReference {
        XcodeProjectReference(
            workspace: workspace,
            project: project,
            scheme: scheme,
            configuration: configuration
        )
    }
}

public final class XcodeBSPConfigurationLoader: Sendable {
    private let rootURL: URL
    private let configurationPath: String

    public init(rootURL: URL, configurationPath: String = ".bsp/xcode.json") {
        self.rootURL = rootURL
        self.configurationPath = configurationPath
    }

    public func findConfiguration() -> URL? {
        let configSearchPaths = [
            // Standard BSP config location for xcode.json
            rootURL.appendingPathComponent(".bsp/xcode.json"),
            // General BSP directory - find first JSON file
            rootURL.appendingPathComponent(".bsp"),
            // Legacy location
            rootURL.appendingPathComponent("buildServer.json")
        ]

        // First try specific xcode.json path
        if FileManager.default.fileExists(atPath: configSearchPaths[0].path) {
            return configSearchPaths[0]
        }

        // Check .bsp directory for any JSON files
        let bspDir = configSearchPaths[1]
        if FileManager.default.fileExists(atPath: bspDir.path) {
            do {
                let jsonFiles = try FileManager.default
                    .contentsOfDirectory(at: bspDir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "json" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }

                if let firstConfig = jsonFiles.first {
                    return firstConfig
                }
            } catch {
                // Continue to legacy location
            }
        }

        // Fallback to legacy location
        if FileManager.default.fileExists(atPath: configSearchPaths[2].path) {
            return configSearchPaths[2]
        }

        return nil
    }

    public func loadConfiguration() throws -> XcodeBSPConfiguration? {
        let configFileURL: URL

        if configurationPath == ".bsp/xcode.json" {
            // Use findConfiguration for default path
            guard let foundURL = findConfiguration() else {
                return nil
            }
            configFileURL = foundURL
        } else {
            // Use explicit path
            configFileURL = rootURL.appendingPathComponent(configurationPath)
            guard FileManager.default.fileExists(atPath: configFileURL.path) else {
                return nil
            }
        }

        let data = try Data(contentsOf: configFileURL)
        let configuration = try JSONDecoder().decode(XcodeBSPConfiguration.self, from: data)
        return configuration
    }

    public func saveConfiguration(_ configuration: XcodeBSPConfiguration) throws {
        let configFileURL = rootURL.appendingPathComponent(configurationPath)
        let bspDirectory = configFileURL.deletingLastPathComponent()

        // Create .bsp directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: bspDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(configuration)
        try data.write(to: configFileURL)
    }
}
