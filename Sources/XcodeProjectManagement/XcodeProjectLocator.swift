import Foundation
import Logger

public enum XcodeProjectError: Error, CustomStringConvertible, Equatable {
    case projectNotFound
    case multipleWorkspaces([URL])
    case multipleProjectsWithoutWorkspace([URL])
    case invalidConfig(String)
    case schemeNotFound(String)
    case targetNotFound(String)
    case buildSettingsNotFound
    case toolchainError(String)
    case indexPathsError(String)
    case dataParsingError(String)
    case noSchemesFound(String)

    public var description: String {
        switch self {
        case .projectNotFound:
            "No .xcodeproj or .xcworkspace found in project directory."
        case let .multipleWorkspaces(urls):
            "Multiple .xcworkspace files found: " +
                urls.map(\.lastPathComponent).joined(separator: ", ") +
                ". Please specify one in .bsp/xcode.json"
        case let .multipleProjectsWithoutWorkspace(urls):
            "Multiple .xcodeproj files found without a workspace: " +
                urls.map(\.lastPathComponent).joined(separator: ", ")
        case let .invalidConfig(reason):
            "Invalid configuration: \(reason)"
        case let .schemeNotFound(scheme):
            "Scheme '\(scheme)' not found in project"
        case let .targetNotFound(target):
            "Target '\(target)' not found in project"
        case .buildSettingsNotFound:
            "Failed to load build settings from xcodebuild"
        case let .toolchainError(message):
            "Toolchain error: \(message)"
        case let .indexPathsError(message):
            "Index paths error: \(message)"
        case let .dataParsingError(message):
            "Data parsing error: \(message)"
        case let .noSchemesFound(message):
            "No schemes found: \(message)"
        }
    }
}

public struct XcodeProjectReference: Codable, Sendable {
    public let workspace: String?
    public let project: String?
    public let scheme: String?
    public let configuration: String?

    public init(
        workspace: String? = nil,
        project: String? = nil,
        scheme: String? = nil,
        configuration: String? = "Debug"
    ) {
        self.workspace = workspace
        self.project = project
        self.scheme = scheme
        self.configuration = configuration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
        project = try container.decodeIfPresent(String.self, forKey: .project)
        scheme = try container.decodeIfPresent(String.self, forKey: .scheme)
        configuration = try container.decodeIfPresent(String.self, forKey: .configuration) ?? "Debug"
    }
}

public enum XcodeProjectLocation: Equatable, Sendable, Codable {
    case explicitWorkspace(URL) // User provided or auto-detected .xcworkspace
    case implicitWorkspace(
        projectURL: URL,
        workspaceURL: URL // {projectURL}/project.xcworkspace
    ) // Converted from .xcodeproj
    case standaloneProject(URL) // .xcodeproj without project.xcworkspace

    var workspaceURL: URL {
        switch self {
        case let .explicitWorkspace(url):
            url
        case let .implicitWorkspace(projectURL: url, workspaceURL: _):
            url
        case let .standaloneProject(url):
            url // For standalone projects, the project itself acts as the workspace
        }
    }

    public var name: String {
        switch self {
        case let .explicitWorkspace(url),
             let .implicitWorkspace(projectURL: url, _),
             let .standaloneProject(url):
            url.lastPathComponent
        }
    }
}

public final class XcodeProjectLocator {
    public init() {}

    // Resolve project with explicit reference
    public func resolveProjectType(
        rootURL: URL,
        xcodeProjectReference: XcodeProjectReference? = nil
    ) throws -> XcodeProjectLocation {
        logger.debug("Resolving Xcode project type at \(rootURL.path)")
        logger.debug("Using reference: \(String(describing: xcodeProjectReference))")
        if let workspace = xcodeProjectReference?.workspace {
            let workspaceURL: URL = if workspace.isRelativePath {
                rootURL.appendingPathComponent(workspace)
            } else {
                URL(fileURLWithPath: workspace)
            }

            guard FileManager.default.fileExists(atPath: workspaceURL.path) else {
                throw XcodeProjectError.invalidConfig("Workspace path does not exist: \(workspace)")
            }
            logger.debug("Resolved explicit workspace: \(workspaceURL.path)")
            return .explicitWorkspace(workspaceURL)
        } else if let project = xcodeProjectReference?.project {
            let projectURL: URL = if project.isRelativePath {
                rootURL.appendingPathComponent(project)
            } else {
                URL(fileURLWithPath: project)
            }

            guard FileManager.default.fileExists(atPath: projectURL.path) else {
                throw XcodeProjectError.invalidConfig("Project path does not exist: \(project)")
            }
            let implicitWorkspace = projectURL.appendingPathComponent("project.xcworkspace")
            guard FileManager.default.fileExists(atPath: implicitWorkspace.path) else {
                throw XcodeProjectError.invalidConfig(
                    "Implicit workspace path does not exist: \(implicitWorkspace.path)"
                )
            }
            logger.debug("Resolved implicit workspace: " + implicitWorkspace.path)
            return .implicitWorkspace(
                projectURL: projectURL,
                workspaceURL: implicitWorkspace
            )
        }

        // If no specific reference provided, fall back to auto-discovery
        return try resolveProjectTypeByAutoDiscovery(rootURL: rootURL)
    }

    // Auto-discovery when no explicit configuration is provided
    private func resolveProjectTypeByAutoDiscovery(rootURL: URL) throws -> XcodeProjectLocation {
        logger.debug("Auto-discovering Xcode project type at \(rootURL.path)")
        let workspaces = findAll(rootURL: rootURL, withExtension: "xcworkspace").filter { !$0.path.contains("/Pods/") }

        if workspaces.count == 1 {
            return .explicitWorkspace(workspaces[0])
        } else if workspaces.count > 1 {
            throw XcodeProjectError.multipleWorkspaces(workspaces)
        }

        let projects = findAll(rootURL: rootURL, withExtension: "xcodeproj")
        if projects.count == 1 {
            let projectURL = projects[0]
            let implicitWorkspaceURL = projectURL.appendingPathComponent("project.xcworkspace")
            guard FileManager.default.fileExists(atPath: implicitWorkspaceURL.path) else {
                logger.debug("No implicit workspace found for project at \(projectURL.path)")
                // For standalone projects without workspace, use the new standaloneProject case
                // This handles older Xcode projects that don't have project.xcworkspace
                return .standaloneProject(projectURL)
            }
            logger.debug("Resolved implicit workspace for project: \(implicitWorkspaceURL.path)")
            // Return implicit workspace created from .xcodeproj
            return .implicitWorkspace(
                projectURL: projectURL,
                workspaceURL: implicitWorkspaceURL
            )
        } else if projects.count > 1 {
            throw XcodeProjectError.multipleProjectsWithoutWorkspace(projects)
        }

        logger.debug("Not found any .xcodeproj or .xcworkspace files in \(rootURL.path)")
        throw XcodeProjectError.projectNotFound
    }

    private func findAll(rootURL: URL, withExtension ext: String) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: .skipsSubdirectoryDescendants
        ) else {
            return []
        }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == ext }
    }
}
