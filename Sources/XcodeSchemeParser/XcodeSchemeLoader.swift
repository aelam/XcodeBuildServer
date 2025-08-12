//
//  XcodeSchemeLoader.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

public struct XcodeSchemeInfoWithPath {
    public let path: URL
    public let scheme: XcodeSchemeInfo

    public init(path: URL, scheme: XcodeSchemeInfo) {
        self.path = path
        self.scheme = scheme
    }
}

/// Loader for Xcode schemes that handles parsing and caching
public struct XcodeSchemeLoader: Sendable {
    let parser: XcodeSchemeParser
    let containerParser: XcodeContainerParser

    public init(
        parser: XcodeSchemeParser = XcodeSchemeParser(),
        containerParser: XcodeContainerParser = XcodeContainerParser()
    ) {
        self.parser = parser
        self.containerParser = containerParser
    }

    /// Load a single scheme from its file URL
    public func loadScheme(from schemeURL: URL) async throws -> XcodeSchemeInfo {
        logger.debug("[scheme parser] Loading scheme from: \(schemeURL.path)")
        return try parser.parseScheme(at: schemeURL)
    }

    /// Load a single scheme from data with specified name
    public func loadScheme(data: Data, name: String) throws -> XcodeSchemeInfo {
        logger.debug("[scheme parser] Loading scheme from data: \(name)")
        return try parser.parseScheme(data: data, name: name)
    }

    /// Load schemes from workspace URL with optional filtering by scheme name
    public func loadSchemes(
        fromWorkspace workspaceURL: URL,
        filterBy schemeNames: [String] = []
    ) throws -> [XcodeSchemeInfo] {
        let schemeFileURLs = containerParser.getSchemeFileURLs(from: workspaceURL)
        let schemesWithPath = try loadSchemesWithPath(from: schemeFileURLs, filterBy: schemeNames)
        return schemesWithPath.map(\.scheme)
    }

    /// Load schemes from project URL with optional filtering by scheme name
    public func loadSchemes(
        fromProject projectURL: URL,
        filterBy schemeNames: [String] = []
    ) throws -> [XcodeSchemeInfo] {
        let schemeFileURLs = containerParser.getSchemeFileURLs(from: projectURL)
        let schemesWithPath = try loadSchemesWithPath(from: schemeFileURLs, filterBy: schemeNames)
        return schemesWithPath.map(\.scheme)
    }

    /// Get the first available scheme name, preferring runnable schemes
    public func getAnyAvailableScheme(from schemes: [XcodeSchemeInfo]) throws -> String {
        guard !schemes.isEmpty else {
            throw XcodeSchemeError.invalidConfig("No schemes found in project")
        }

        // Prefer schemes with runnable targets (like Xcode does)
        if let runnableScheme = schemes.first(where: { !$0.runTargets.isEmpty }) {
            return runnableScheme.name
        }

        // If no runnable scheme, prefer schemes with buildable targets
        if let buildableScheme = schemes.first(where: { !$0.buildableTargets.isEmpty }) {
            return buildableScheme.name
        }

        // Fall back to first scheme
        return schemes.first!.name
    }

    /// Load schemes from scheme file URLs with optional filtering by scheme names
    func loadSchemes(
        from schemeFileURLs: [URL],
        filterBy schemeNames: [String] = []
    ) throws -> [XcodeSchemeInfo] {
        logger.debug("[scheme parser]found \(schemeFileURLs.count) scheme files")

        // Filter scheme files by names if specified
        let filteredSchemeFiles: [URL]
        if !schemeNames.isEmpty {
            filteredSchemeFiles = schemeFileURLs.filter { url in
                let fileName = url.deletingPathExtension().lastPathComponent
                return schemeNames.contains(fileName)
            }
            guard !filteredSchemeFiles.isEmpty else {
                throw XcodeSchemeError.schemeNotFound(schemeNames.joined(separator: ", "))
            }
        } else {
            filteredSchemeFiles = schemeFileURLs
        }

        var schemes: [XcodeSchemeInfo] = []

        for schemeFile in filteredSchemeFiles {
            do {
                logger.debug("[scheme parser]scheme: \(schemeFile.path)")
                var schemeInfo = try parser.parseScheme(at: schemeFile)

                // Set scheme name from file name if not set
                if schemeInfo.name.isEmpty {
                    let parsedSchemeName = schemeFile.deletingPathExtension().lastPathComponent
                    schemeInfo = XcodeSchemeInfo(
                        name: parsedSchemeName,
                        buildAction: schemeInfo.buildAction,
                        testAction: schemeInfo.testAction,
                        launchAction: schemeInfo.launchAction,
                        profileAction: schemeInfo.profileAction,
                        analyzeAction: schemeInfo.analyzeAction,
                        archiveAction: schemeInfo.archiveAction
                    )
                }

                schemes.append(schemeInfo)
                logger.debug("Loaded scheme: \(schemeInfo.name) with \(schemeInfo.targets.count) targets")
            } catch {
                logger.warning("Failed to parse scheme at \(schemeFile.path): \(error)")
            }
        }

        logger.info("Loaded \(schemes.count) schemes from project")
        return schemes
    }

    /// Load schemes from scheme file URLs with optional filtering by scheme names, returning path information
    func loadSchemesWithPath(
        from schemeFileURLs: [URL],
        filterBy schemeNames: [String] = []
    ) throws -> [XcodeSchemeInfoWithPath] {
        logger.debug("[scheme parser]found \(schemeFileURLs.count) scheme files")

        // Filter scheme files by names if specified
        let filteredSchemeFiles: [URL]
        if !schemeNames.isEmpty {
            filteredSchemeFiles = schemeFileURLs.filter { url in
                let fileName = url.deletingPathExtension().lastPathComponent
                return schemeNames.contains(fileName)
            }
            guard !filteredSchemeFiles.isEmpty else {
                throw XcodeSchemeError.schemeNotFound(schemeNames.joined(separator: ", "))
            }
        } else {
            filteredSchemeFiles = schemeFileURLs
        }

        var schemes: [XcodeSchemeInfoWithPath] = []

        for schemeFile in filteredSchemeFiles {
            do {
                logger.debug("[scheme parser]scheme: \(schemeFile.path)")
                var schemeInfo = try parser.parseScheme(at: schemeFile)

                // Set scheme name from file name if not set
                if schemeInfo.name.isEmpty {
                    let parsedSchemeName = schemeFile.deletingPathExtension().lastPathComponent
                    schemeInfo = XcodeSchemeInfo(
                        name: parsedSchemeName,
                        buildAction: schemeInfo.buildAction,
                        testAction: schemeInfo.testAction,
                        launchAction: schemeInfo.launchAction,
                        profileAction: schemeInfo.profileAction,
                        analyzeAction: schemeInfo.analyzeAction,
                        archiveAction: schemeInfo.archiveAction
                    )
                }

                let schemeWithPath = XcodeSchemeInfoWithPath(path: schemeFile, scheme: schemeInfo)
                schemes.append(schemeWithPath)
                logger.debug("Loaded scheme: \(schemeInfo.name) with \(schemeInfo.targets.count) targets")
            } catch {
                logger.warning("Failed to parse scheme at \(schemeFile.path): \(error)")
            }
        }

        logger.info("Loaded \(schemes.count) schemes from project")
        return schemes
    }

    /// Get a target name from a scheme
    public func getTargetFromScheme(schemeName: String, in schemes: [XcodeSchemeInfo]) throws -> String {
        // Find the scheme
        guard let scheme = schemes.first(where: { $0.name == schemeName }) else {
            throw XcodeSchemeError.schemeNotFound(schemeName)
        }

        // Get the first buildable target from the scheme
        guard let target = scheme.firstBuildableTarget else {
            throw XcodeSchemeError.invalidConfig("No buildable targets found in scheme '\(schemeName)'")
        }

        return target.targetName
    }

    /// Get scheme info by name
    public func getScheme(named schemeName: String, from schemes: [XcodeSchemeInfo]) throws -> XcodeSchemeInfo {
        guard let scheme = schemes.first(where: { $0.name == schemeName }) else {
            throw XcodeSchemeError.schemeNotFound(schemeName)
        }

        return scheme
    }
}
