//
//  XcodeToBSPAdapter.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeProjectManagement

/// Adapter for converting Xcode project information to BSP BuildTarget objects
public actor XcodeToBSPAdapter {
    private let projectManager: XcodeProjectManager

    public init(projectManager: XcodeProjectManager) {
        self.projectManager = projectManager
    }

    /// Create all BuildTarget objects for BSP from the current project
    public func createBuildTargets() async throws -> [BuildTarget] {
        let currentProject = try await getCurrentProject()
        var buildTargets: [BuildTarget] = []

        for schemeInfo in currentProject.schemeInfoList {
            let targets = try await projectManager.loadTargets(for: schemeInfo.name)

            for targetInfo in targets {
                let buildTarget = await createBuildTarget(
                    from: targetInfo,
                    scheme: schemeInfo.name,
                    projectBasicInfo: currentProject
                )
                buildTargets.append(buildTarget)
            }
        }

        return buildTargets
    }

    /// Get current project info
    private func getCurrentProject() async throws -> XcodeProjectBasicInfo {
        guard let currentProject = await projectManager.currentProjectInfo else {
            throw XcodeProjectError.invalidConfig("Project not loaded. Call loadProjectBasicInfo() first.")
        }
        return currentProject
    }

    /// Create a single BuildTarget directly from XcodeTargetInfo
    private func createBuildTarget(
        from targetInfo: XcodeTargetInfo,
        scheme: String,
        projectBasicInfo: XcodeProjectBasicInfo
    ) async -> BuildTarget {
        // Create BSP target identifier
        let targetIdentifier = createBSPTargetIdentifier(
            targetName: targetInfo.name,
            scheme: scheme,
            projectBasicInfo: projectBasicInfo
        )
        let targetID = createBuildTargetIdentifier(from: targetIdentifier)

        let baseDirectory = try? URI(string: projectBasicInfo.rootURL.absoluteString)
        let displayName = "\(scheme)/\(targetInfo.name)"
        let tags = classifyTarget(targetInfo)
        let languages = mapLanguages(from: targetInfo.supportedLanguages)
        let capabilities = createCapabilities(for: targetInfo)
        let sourceKitData = await createSourceKitData()

        return BuildTarget(
            id: targetID,
            displayName: displayName,
            baseDirectory: baseDirectory,
            tags: tags,
            languageIds: languages,
            dependencies: [], // TODO: Extract dependencies from build settings
            capabilities: capabilities,
            dataKind: .sourceKit,
            data: sourceKitData?.encodeToLSPAny()
        )
    }

    /// Create BSP target identifier string from XcodeProjectBasicInfo and target details
    private func createBSPTargetIdentifier(
        targetName: String,
        scheme: String,
        projectBasicInfo: XcodeProjectBasicInfo
    ) -> String {
        return "xcode:///\(projectBasicInfo.projectLocation.name)/\(scheme)/\(targetName)"
    }

    /// Convert string identifier to BuildTargetIdentifier
    private func createBuildTargetIdentifier(from identifier: String) -> BuildTargetIdentifier {
        if let uri = try? URI(string: identifier) {
            return BuildTargetIdentifier(uri: uri)
        } else {
            // swiftlint:disable:next force_try
            let fallbackURI = try! URI(string: "xcode:///unknown/unknown/unknown")
            return BuildTargetIdentifier(uri: fallbackURI)
        }
    }

    /// Classify target into BuildTargetTag categories
    private func classifyTarget(_ targetInfo: XcodeTargetInfo) -> [BuildTargetTag] {
        var tags: [BuildTargetTag] = []

        if targetInfo.name.contains("UITest") {
            tags.append(.integrationTest)
        } else if targetInfo.isTestTarget {
            tags.append(.test)
        } else if targetInfo.isApplicationTarget {
            tags.append(.application)
        } else if targetInfo.isLibraryTarget {
            tags.append(.library)
        } else {
            // Default to library for unknown types
            tags.append(.library)
        }

        return tags
    }

    /// Map language strings to Language enum
    private func mapLanguages(from languageStrings: Set<String>) -> [Language] {
        languageStrings.compactMap { languageString in
            switch languageString {
            case "swift":
                .swift
            case "objective-c":
                .objective_c
            case "c":
                .c
            case "cpp":
                .cpp
            default:
                nil
            }
        }
    }

    /// Create capabilities for BSP target
    private func createCapabilities(for targetInfo: XcodeTargetInfo) -> BuildTargetCapabilities {
        BuildTargetCapabilities(
            canCompile: true, // All Xcode targets can compile
            canTest: targetInfo.isTestTarget,
            canRun: targetInfo.isRunnableTarget,
            canDebug: true // Xcode supports debugging for all targets
        )
    }

    /// Create SourceKit data for the target
    private func createSourceKitData() async -> SourceKitBuildTarget? {
        let toolchain = await projectManager.getToolchain()
        guard let installation = await toolchain.getSelectedInstallation() else {
            return nil
        }

        let toolchainURI = try? URI(string: installation.path.absoluteString)
        return SourceKitBuildTarget(toolchain: toolchainURI)
    }
}
