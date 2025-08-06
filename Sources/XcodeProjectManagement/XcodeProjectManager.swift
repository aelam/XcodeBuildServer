//
//  XcodeProjectManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public struct XcodeTargetInfo: Sendable {
    public let name: String
    public let productType: String?
    public let buildSettings: [String: String]

    public var isTestTarget: Bool {
        name.contains("Test") || productType?.contains("unit-test") == true || productType?
            .contains("ui-testing") == true
    }

    public var isUITestTarget: Bool {
        name.contains("UITest") || productType?.contains("ui-testing") == true
    }

    public var isRunnableTarget: Bool {
        productType?.contains("application") == true || productType?.contains("app-extension") == true
    }

    public var isApplicationTarget: Bool {
        productType?.contains("application") == true
    }

    public var isLibraryTarget: Bool {
        productType?.contains("framework") == true ||
            productType?.contains("static-library") == true ||
            productType?.contains("dynamic-library") == true
    }

    public var supportedLanguages: Set<String> {
        var languages: Set<String> = []

        if buildSettings["SWIFT_VERSION"] != nil {
            languages.insert("swift")
        }
        if buildSettings["CLANG_ENABLE_OBJC_ARC"] == "YES" {
            languages.insert("objective-c")
        }
        if buildSettings["GCC_VERSION"] != nil {
            languages.insert("c")
        }
        if buildSettings["CLANG_CXX_LANGUAGE_STANDARD"] != nil {
            languages.insert("cpp")
        }

        // Default for Xcode projects
        if languages.isEmpty {
            languages = ["swift", "objective-c"]
        }

        return languages
    }

    public init(name: String, productType: String?, buildSettings: [String: String]) {
        self.name = name
        self.productType = productType
        self.buildSettings = buildSettings
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
    private let toolchain: XcodeToolchain

    public init(rootURL: URL, configFile: String = ".bsp/xcode.json", toolchain: XcodeToolchain = XcodeToolchain()) {
        self.locator = XcodeProjectLocator(root: rootURL, configFile: configFile)
        self.toolchain = toolchain
    }

    public func loadProject(scheme: String? = nil, configuration: String = "Debug") async throws -> XcodeProjectInfo {
        try await toolchain.initialize()

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

    public func getAvailableTargets() async throws -> [String] {
        guard let project = currentProject else {
            throw XcodeProjectError.notFound
        }

        let arguments = buildBasicArguments(for: project) + ["-list"]
        let output = try await runXcodeBuild(arguments: arguments)
        return parseTargets(from: output ?? "")
    }

    public func getTargetBuildSettings(target: String) async throws -> [String: String] {
        guard let project = currentProject else {
            throw XcodeProjectError.notFound
        }

        var arguments = buildBasicArguments(for: project)
        arguments.append(contentsOf: ["-target", target, "-showBuildSettings"])

        let output = try await runXcodeBuild(arguments: arguments)
        return parseBuildSettings(from: output ?? "")
    }

    public func extractTargetInfo() async throws -> [XcodeTargetInfo] {
        let targets = try await getAvailableTargets()
        var targetInfos: [XcodeTargetInfo] = []

        for target in targets {
            let buildSettings = try await getTargetBuildSettings(target: target)
            let productType = buildSettings["PRODUCT_TYPE"]

            let targetInfo = XcodeTargetInfo(
                name: target,
                productType: productType,
                buildSettings: buildSettings
            )
            targetInfos.append(targetInfo)
        }

        return targetInfos
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

    private func parseTargets(from output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var targets: [String] = []
        var inTargetsSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "Targets:" {
                inTargetsSection = true
                continue
            }

            if inTargetsSection {
                if trimmed.isEmpty || trimmed.hasPrefix("Build Configurations:") || trimmed.hasPrefix("Schemes:") {
                    break
                }

                if !trimmed.isEmpty {
                    targets.append(trimmed)
                }
            }
        }

        return targets
    }

    private func parseBuildSettings(from output: String) -> [String: String] {
        let lines = output.components(separatedBy: .newlines)
        var buildSettings: [String: String] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Look for lines with format "KEY = value"
            if let equalIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)

                if !key.isEmpty {
                    buildSettings[key] = value
                }
            }
        }

        return buildSettings
    }

    private func runXcodeBuild(arguments: [String]) async throws -> String? {
        let (output, _) = try await toolchain.executeXcodeBuild(arguments: arguments, workingDirectory: locator.root)
        return output
    }
}
