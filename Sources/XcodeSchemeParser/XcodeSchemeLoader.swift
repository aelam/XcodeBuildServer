//
//  XcodeSchemeLoader.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

/// Loader for Xcode schemes that handles parsing and caching
public struct XcodeSchemeLoader: Sendable {
    private let parser: XcodeSchemeParser
    private let containerParser: XcodeContainerParser

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
        return try loadSchemes(from: schemeFileURLs, filterBy: schemeNames)
    }

    /// Load schemes from project URL with optional filtering by scheme name
    public func loadSchemes(
        fromProject projectURL: URL,
        filterBy schemeNames: [String] = []
    ) throws -> [XcodeSchemeInfo] {
        let schemeFileURLs = containerParser.getSchemeFileURLs(from: projectURL)
        return try loadSchemes(from: schemeFileURLs, filterBy: schemeNames)
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

    /// Get all runnable target names from all schemes
    public func getAllRunnableTargets(from schemes: [XcodeSchemeInfo]) -> Set<String> {
        var runnableTargets: Set<String> = []

        for scheme in schemes {
            for target in scheme.runTargets {
                runnableTargets.insert(target.targetName)
            }
        }

        return runnableTargets
    }

    /// Get all testable target names from all schemes
    public func getAllTestableTargets(from schemes: [XcodeSchemeInfo]) -> Set<String> {
        var testableTargets: Set<String> = []

        for scheme in schemes {
            for target in scheme.testTargets {
                testableTargets.insert(target.targetName)
            }
        }

        return testableTargets
    }

    /// Get all unique target names from all schemes
    public func getAllTargetNames(from schemes: [XcodeSchemeInfo]) -> Set<String> {
        var targets: Set<String> = []

        for scheme in schemes {
            for target in scheme.targets {
                targets.insert(target.targetName)
            }
        }

        return targets
    }

    /// Get all buildable target names from all schemes
    public func getAllBuildableTargets(from schemes: [XcodeSchemeInfo]) -> Set<String> {
        var buildableTargets: Set<String> = []

        for scheme in schemes {
            for target in scheme.buildableTargets {
                buildableTargets.insert(target.targetName)
            }
        }

        return buildableTargets
    }

    /// Get launch configurations for all schemes
    public func getLaunchConfigurations(from schemes: [XcodeSchemeInfo]) -> [String: String] {
        var configurations: [String: String] = [:]

        for scheme in schemes {
            if let launchConfig = scheme.runConfiguration {
                configurations[scheme.name] = launchConfig
            }
        }

        return configurations
    }

    /// Get test configurations for all schemes
    public func getTestConfigurations(from schemes: [XcodeSchemeInfo]) -> [String: String] {
        var configurations: [String: String] = [:]

        for scheme in schemes {
            if let testConfig = scheme.testConfiguration {
                configurations[scheme.name] = testConfig
            }
        }

        return configurations
    }

    /// Get all environment variables from launch actions
    public func getAllEnvironmentVariables(from schemes: [XcodeSchemeInfo]) -> [String: [String: String]] {
        var allEnvVars: [String: [String: String]] = [:]

        for scheme in schemes {
            let envVars = scheme.enabledEnvironmentVariables
            if !envVars.isEmpty {
                allEnvVars[scheme.name] = envVars
            }
        }

        return allEnvVars
    }

    /// Get all command line arguments from launch actions
    public func getAllCommandLineArguments(from schemes: [XcodeSchemeInfo]) -> [String: [String]] {
        var allArgs: [String: [String]] = [:]

        for scheme in schemes {
            let args = scheme.enabledArguments
            if !args.isEmpty {
                allArgs[scheme.name] = args
            }
        }

        return allArgs
    }

    /// Get schemes that contain a specific target
    public func getSchemes(containing targetName: String, from schemes: [XcodeSchemeInfo]) -> [XcodeSchemeInfo] {
        schemes.filter { scheme in
            scheme.targets.contains { $0.targetName == targetName }
        }
    }

    /// Get the preferred scheme for a target (prioritizes runnable schemes)
    public func getPreferredScheme(for targetName: String, from schemes: [XcodeSchemeInfo]) -> XcodeSchemeInfo? {
        let schemesWithTarget = getSchemes(containing: targetName, from: schemes)

        // Prefer schemes where the target is runnable
        if let runnableScheme = schemesWithTarget.first(where: { scheme in
            scheme.targets.contains { $0.targetName == targetName && $0.buildForRunning }
        }) {
            return runnableScheme
        }

        // Otherwise return the first scheme containing the target
        return schemesWithTarget.first
    }

    /// Validate scheme consistency
    public func validateSchemes(_ schemes: [XcodeSchemeInfo]) throws {
        guard !schemes.isEmpty else {
            throw XcodeSchemeError.invalidConfig("No schemes found in project")
        }

        // Validate each scheme has at least one target
        for scheme in schemes where scheme.targets.isEmpty {
            logger.warning("Scheme '\(scheme.name)' has no targets")
        }
    }
}
