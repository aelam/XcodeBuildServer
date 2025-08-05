//
//  XcodeProjectManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// Utility function to check if xcodebuild is available on the system
public func isXcodeBuildAvailable() -> Bool {
    // First check if xcodebuild exists
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["xcodebuild"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return false }
    } catch {
        return false
    }

    // Then check if xcodebuild can actually run (test with -version)
    let testProcess = Process()
    testProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
    testProcess.arguments = ["-version"]

    let testPipe = Pipe()
    testProcess.standardOutput = testPipe
    testProcess.standardError = testPipe

    do {
        try testProcess.run()
        testProcess.waitUntilExit()
        return testProcess.terminationStatus == 0
    } catch {
        return false
    }
}

public struct XcodeProjectInfo: Sendable {
    public let rootURL: URL
    public let projectType: XcodeProjectType
    public let scheme: String?
    public let configuration: String
    public let derivedDataPath: URL?

    public init(
        rootURL: URL,
        projectType: XcodeProjectType,
        scheme: String?,
        configuration: String = "Debug",
        derivedDataPath: URL? = nil
    ) {
        self.rootURL = rootURL
        self.projectType = projectType
        self.scheme = scheme
        self.configuration = configuration
        self.derivedDataPath = derivedDataPath
    }

    public var workspaceURL: URL {
        switch projectType {
        case let .explicitWorkspace(url), let .implicitProjectWorkspace(url):
            url
        }
    }

    public var workspaceName: String {
        workspaceURL.lastPathComponent
    }

    public var projectName: String? {
        switch projectType {
        case .explicitWorkspace:
            nil
        case let .implicitProjectWorkspace(url):
            url.deletingLastPathComponent().lastPathComponent
        }
    }
}

public actor XcodeProjectManager {
    private let locator: XcodeProjectLocator
    private(set) var currentProject: XcodeProjectInfo?

    public init(rootURL: URL, configFile: String = ".bsp/xcode.json") {
        self.locator = XcodeProjectLocator(root: rootURL, configFile: configFile)
    }

    public func loadProject(scheme: String? = nil, configuration: String = "Debug") async throws -> XcodeProjectInfo {
        let projectType = try locator.resolveProject()
        let rootURL = locator.root

        let resolvedScheme = try await resolveScheme(for: projectType, fallback: scheme)
        let project = XcodeProjectInfo(
            rootURL: rootURL,
            projectType: projectType,
            scheme: resolvedScheme,
            configuration: configuration
        )

        self.currentProject = project
        return project
    }

    public func getAvailableSchemes() async throws -> [String] {
        guard let project = currentProject else {
            throw XcodeProjectError.notFound
        }

        let arguments = buildBasicArguments(for: project) + ["-list"]
        let output = try await runXcodeBuild(arguments: arguments)
        return parseSchemes(from: output ?? "")
    }

    public func getAvailableConfigurations() async throws -> [String] {
        guard let project = currentProject else {
            throw XcodeProjectError.notFound
        }

        let arguments = buildBasicArguments(for: project) + ["-list"]
        let output = try await runXcodeBuild(arguments: arguments)
        return parseConfigurations(from: output ?? "")
    }

    private func resolveScheme(for projectType: XcodeProjectType, fallback: String?) async throws -> String? {
        if let fallback {
            return fallback
        }

        let tempProject = XcodeProjectInfo(
            rootURL: locator.root,
            projectType: projectType,
            scheme: nil,
            configuration: "Debug"
        )

        let arguments = buildBasicArguments(for: tempProject) + ["-list"]
        let output = try await runXcodeBuild(arguments: arguments)
        let schemes = parseSchemes(from: output ?? "")

        return schemes.first
    }

    private func buildBasicArguments(for project: XcodeProjectInfo) -> [String] {
        var arguments: [String] = []

        switch project.projectType {
        case let .explicitWorkspace(url):
            arguments.append(contentsOf: ["-workspace", url.path])
        case let .implicitProjectWorkspace(url):
            let projectURL = url.deletingLastPathComponent()
            arguments.append(contentsOf: ["-project", projectURL.path])
        }

        return arguments
    }

    private func parseSchemes(from output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var schemes: [String] = []
        var inSchemesSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "Schemes:" {
                inSchemesSection = true
                continue
            }

            if inSchemesSection {
                if trimmed.isEmpty || trimmed.hasPrefix("Build Configurations:") {
                    break
                }

                if !trimmed.isEmpty {
                    schemes.append(trimmed)
                }
            }
        }

        return schemes
    }

    private func parseConfigurations(from output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var configurations: [String] = []
        var inConfigSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "Build Configurations:" {
                inConfigSection = true
                continue
            }

            if inConfigSection {
                if trimmed.isEmpty {
                    break
                }

                if !trimmed.isEmpty, !trimmed.contains("If no build configuration") {
                    configurations.append(trimmed)
                }
            }
        }

        return configurations
    }

    private func runXcodeBuild(arguments: [String]) async throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
