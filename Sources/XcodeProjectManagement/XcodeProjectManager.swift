//
//  XcodeProjectManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

public struct XcodeListInfo: Codable, Sendable {
    public let project: XcodeListProject?

    public struct XcodeListProject: Codable, Sendable {
        public let schemes: [String]
        public let targets: [String]
        public let configurations: [String]
    }
}

public struct XcodeTargetInfo: Sendable {
    public let name: String
    public let productType: String?
    public let buildSettings: [String: String]

    public var xcodeProductType: XcodeProductType? {
        guard let productType else { return nil }
        return XcodeProductType(rawValue: productType)
    }

    public var isTestTarget: Bool {
        xcodeProductType?.isTestType == true
    }

    public var isUITestTarget: Bool {
        xcodeProductType == .uiTest
    }

    public var isRunnableTarget: Bool {
        xcodeProductType?.isRunnableType == true
    }

    public var isApplicationTarget: Bool {
        xcodeProductType?.isApplicationType == true
    }

    public var isLibraryTarget: Bool {
        xcodeProductType?.isLibraryType == true
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

        let commandBuilder = XcodeBuildCommandBuilder(projectInfo: project, toolchain: toolchain)
        let output = try await commandBuilder.executeCommand(options: .listSchemesJSON)

        if let output, let data = output.data(using: .utf8) {
            do {
                let listInfo = try JSONDecoder().decode(XcodeListInfo.self, from: data)
                return listInfo.project?.schemes ?? []
            } catch {
                // Fallback to text parsing if JSON fails
                return parseSchemes(from: output)
            }
        }

        return []
    }

    public func getAvailableConfigurations() async throws -> [String] {
        guard let project = currentProject else {
            throw XcodeProjectError.notFound
        }

        let commandBuilder = XcodeBuildCommandBuilder(projectInfo: project, toolchain: toolchain)
        let output = try await commandBuilder.executeCommand(options: .listSchemesJSON)

        if let output, let data = output.data(using: .utf8) {
            do {
                let listInfo = try JSONDecoder().decode(XcodeListInfo.self, from: data)
                return listInfo.project?.configurations ?? []
            } catch {
                // Fallback to text parsing if JSON fails
                return parseConfigurations(from: output)
            }
        }

        return []
    }

    public func getAvailableTargets() async throws -> [String] {
        guard let project = currentProject else {
            throw XcodeProjectError.notFound
        }

        let commandBuilder = XcodeBuildCommandBuilder(projectInfo: project, toolchain: toolchain)
        let output = try await commandBuilder.executeCommand(options: .listSchemesJSON)

        if let output, let data = output.data(using: .utf8) {
            do {
                let listInfo = try JSONDecoder().decode(XcodeListInfo.self, from: data)
                return listInfo.project?.targets ?? []
            } catch {
                // Fallback to text parsing if JSON fails
                return parseTargets(from: output)
            }
        }

        return []
    }

    public func getTargetBuildSettings(target: String) async throws -> [String: String] {
        guard let project = currentProject else {
            throw XcodeProjectError.notFound
        }

        let commandBuilder = XcodeBuildCommandBuilder(projectInfo: project, toolchain: toolchain)
        let options = XcodeBuildOptions(showBuildSettings: true, customFlags: ["-target", target])
        let output = try await commandBuilder.executeCommand(options: options)
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

        let tempCommandBuilder = XcodeBuildCommandBuilder(projectInfo: tempProject, toolchain: toolchain)
        let output = try await tempCommandBuilder.executeCommand(options: .listSchemesJSON)

        if let output, let data = output.data(using: .utf8) {
            do {
                let listInfo = try JSONDecoder().decode(XcodeListInfo.self, from: data)
                return listInfo.project?.schemes.first
            } catch {
                // Fallback to text parsing if JSON fails
                let schemes = parseSchemes(from: output)
                return schemes.first
            }
        }

        return nil
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
}
