import Foundation

enum XcodeProjectError: Error, CustomStringConvertible {
    case notFound
    case multipleWorkspaces([URL])
    case invalidConfig(String)

    var description: String {
        switch self {
        case .notFound:
            return "No .xcodeproj or .xcworkspace found in project directory."
        case .multipleWorkspaces(let urls):
            return "Multiple .xcworkspace files found: \(urls.map { $0.lastPathComponent }.joined(separator: ", ")). Please specify one in .bspconfig.json"
        case .invalidConfig(let reason):
            return "Invalid bsp config: \(reason)"
        }
    }
}

struct BSPConfig: Codable {
    let workspace: String?
    let project: String?
}

enum XcodeProjectType {
    case explicitWorkspace(URL)       // User provided or auto-detected .xcworkspace
    case implicitProjectWorkspace(URL) // Converted from .xcodeproj
}

final class XcodeProjectLocator {
    let root: URL
    let configFile = ".bsp/xcode.json"

    init(root: URL) {
        self.root = root
    }

    func resolveProject() throws -> XcodeProjectType {
        if let config = try? loadConfig() {
            if let workspace = config.workspace {
                let workspaceURL = root.appendingPathComponent(workspace)
                guard FileManager.default.fileExists(atPath: workspaceURL.path) else {
                    throw XcodeProjectError.invalidConfig("Workspace path does not exist: \(workspace)")
                }
                return .explicitWorkspace(workspaceURL)
            } else if let project = config.project {
                let projectURL = root.appendingPathComponent(project)
                guard FileManager.default.fileExists(atPath: projectURL.path) else {
                    throw XcodeProjectError.invalidConfig("Project path does not exist: \(project)")
                }
                let implicitWorkspace = projectURL.appendingPathComponent("project.xcworkspace")
                return .implicitProjectWorkspace(implicitWorkspace)
            }
        }

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
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == ext }
    }

    private func loadConfig() throws -> BSPConfig? {
        let configURL = root.appendingPathComponent(configFile)
        guard FileManager.default.fileExists(atPath: configURL.path) else { return nil }
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(BSPConfig.self, from: data)
    }
}
