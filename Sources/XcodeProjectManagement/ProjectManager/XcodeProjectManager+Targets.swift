import Foundation
import Logger
import XcodeProj

extension XcodeProjectManager {
    /// Load actual targets, handling both workspace and project cases
    func loadActualTargets(
        projectLocation: XcodeProjectLocation
    ) async throws -> [XcodeTarget] {
        switch projectLocation {
        case .explicitWorkspace:
            // For workspace, load containers to get actual targets from projects
            try await loadTargetsFromWorkspaceContainers(projectLocation: projectLocation)
        case let .implicitWorkspace(projectURL, _):
            // For project, load targets using XcodeProj
            try loadTargetsFromXcodeProj(projectPath: projectURL)
        case let .standaloneProject(projectURL):
            // For standalone project, load targets using XcodeProj
            try loadTargetsFromXcodeProj(projectPath: projectURL)
        }
    }

    /// Load targets from workspace containers using XcodeProj
    private func loadTargetsFromWorkspaceContainers(
        projectLocation: XcodeProjectLocation
    ) async throws -> [XcodeTarget] {
        guard case let .explicitWorkspace(workspaceURL) = projectLocation else {
            return []
        }

        do {
            // Use XcodeProj to parse workspace
            let workspace = try XCWorkspace(pathString: workspaceURL.path)
            var allTargets: [XcodeTarget] = []

            // Get all project references from workspace
            for element in workspace.data.children {
                if case let .file(fileRef) = element,
                   fileRef.location.path.hasSuffix(".xcodeproj") {
                    // Resolve project path relative to workspace
                    let projectPath = resolveProjectPath(
                        from: fileRef.location,
                        workspaceURL: workspaceURL
                    )

                    if let projectPath {
                        do {
                            let projectTargets = try loadTargetsFromXcodeProj(projectPath: projectPath)
                            allTargets.append(contentsOf: projectTargets)
                        } catch {
                            logger.error("Failed to load targets from project \(projectPath): \(error)")
                            // Continue with other projects
                        }
                    }
                }
            }

            logger.debug("Loaded \(allTargets.count) targets from workspace \(workspaceURL.path)")

            return allTargets
        } catch {
            logger.error("Failed to parse workspace \(workspaceURL.path): \(error)")
            return []
        }
    }

    /// Load targets from XcodeProj directly
    func loadTargetsFromXcodeProj(projectPath: URL) throws -> [XcodeTarget] {
        var targets = [XcodeTarget]()
        let project = try XcodeProj(pathString: projectPath.path)
        for target in project.pbxproj.nativeTargets {
            let buildConfiguration = target.buildConfigurationList?.buildConfigurations.first?.buildSettings
            let SDKROOT: String = buildConfiguration?["SDKROOT"] as? String ?? "iphoneos"
            let platform = XcodeTarget.Platform(rawValue: SDKROOT) ?? .iOS
            let pbxProductType = target.productType ?? .none
            let productType = XcodeProductType(rawValue: pbxProductType.rawValue) ?? .none
            targets.append(
                XcodeTarget(
                    name: target.name,
                    projectURL: projectPath,
                    productName: target.productName,
                    isFromWorkspace: false,
                    platform: platform,
                    productType: productType
                )
            )
        }
        return targets
    }
}
