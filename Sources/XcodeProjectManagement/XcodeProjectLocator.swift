import Foundation

public enum XcodeProjectError: Error, CustomStringConvertible, Equatable {
    case notFound
    case multipleWorkspaces([URL])
    case invalidConfig(String)

    public var description: String {
        switch self {
        case .notFound:
            "No .xcodeproj or .xcworkspace found in project directory."
        case let .multipleWorkspaces(urls):
            "Multiple .xcworkspace files found: " +
                urls.map(\.lastPathComponent).joined(separator: "\n") +
                ", " + "Please specify one in .bspconfig.json"
        case let .invalidConfig(reason):
            "Invalid bsp config: \(reason)"
        }
    }
}

public struct XcodeProjectReference: Codable, Sendable {
    public let workspace: String?
    public let project: String?
    public let scheme: String?
    public let configuration: String?

    public init(workspace: String? = nil, project: String? = nil, scheme: String? = nil, configuration: String? = nil) {
        self.workspace = workspace
        self.project = project
        self.scheme = scheme
        self.configuration = configuration
    }
}

public enum XcodeProjectType: Equatable, Sendable {
    case explicitWorkspace(URL) // User provided or auto-detected .xcworkspace
    case implicitProjectWorkspace(URL) // Converted from .xcodeproj
}

public final class XcodeProjectLocator {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    // Resolve project with explicit reference
    public func resolveProject(from reference: XcodeProjectReference) throws -> XcodeProjectType {
        if let workspace = reference.workspace {
            let workspaceURL = root.appendingPathComponent(workspace)
            guard FileManager.default.fileExists(atPath: workspaceURL.path) else {
                throw XcodeProjectError.invalidConfig("Workspace path does not exist: \(workspace)")
            }
            return .explicitWorkspace(workspaceURL)
        } else if let project = reference.project {
            let projectURL = root.appendingPathComponent(project)
            guard FileManager.default.fileExists(atPath: projectURL.path) else {
                throw XcodeProjectError.invalidConfig("Project path does not exist: \(project)")
            }
            let implicitWorkspace = projectURL.appendingPathComponent("project.xcworkspace")
            return .implicitProjectWorkspace(implicitWorkspace)
        }

        // If no specific reference provided, fall back to auto-discovery
        return try resolveProjectByAutoDiscovery()
    }

    // Auto-discovery when no explicit configuration is provided
    public func resolveProjectByAutoDiscovery() throws -> XcodeProjectType {
        let workspaces = findAll(withExtension: "xcworkspace").filter { !$0.path.contains("/Pods/") }

        if workspaces.count == 1 {
            return .explicitWorkspace(workspaces[0])
        } else if workspaces.count > 1 {
            throw XcodeProjectError.multipleWorkspaces(workspaces)
        }

        let projects = findAll(withExtension: "xcodeproj")
        if projects.count == 1 {
            let implicitWorkspace = projects[0].appendingPathComponent("project.xcworkspace")
            return .implicitProjectWorkspace(implicitWorkspace)
        }

        throw XcodeProjectError.notFound
    }

    private func findAll(withExtension ext: String) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
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
