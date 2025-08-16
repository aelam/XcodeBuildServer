import Foundation
import PathKit
import XcodeProj

struct XCSchemeManager {
    func listSchemes(
        projectLocation: XcodeProjectLocation,
        includeUserSchemes: Bool = true
    ) throws -> [XcodeScheme] {
        var result: [XcodeScheme] = []
        switch projectLocation {
        case let .explicitWorkspace(workspaceURL):
            // Handle explicit workspace
            let wsPath = Path(workspaceURL.path)
            let ws = try XCWorkspace(path: wsPath)

            // A. workspace 自身的 schemes
            result += loadSchemes(
                at: wsPath,
                containerName: "workspace",
                includeUserSchemes: includeUserSchemes
            )

            // B. workspace 引用的每个 .xcodeproj 的 schemes
            let children = ws.data.children
            for child in children {
                guard case let .file(fileRef) = child,
                      fileRef.location.path.hasSuffix(".xcodeproj") else { continue }

                let projPath = resolveProjectPath(from: fileRef.location.path, workspacePath: wsPath)

                if projPath.exists {
                    result += loadSchemes(
                        at: projPath,
                        containerName: projPath.lastComponentWithoutExtension,
                        includeUserSchemes: includeUserSchemes
                    )
                }
            }

        case let .implicitWorkspace(projectURL, workspaceURL):
            // Handle implicit workspace (from .xcodeproj)
            let projPath = Path(projectURL.path)
            let wsPath = Path(workspaceURL.path)

            // Load schemes from both project and its implicit workspace
            result += loadSchemes(
                at: projPath,
                containerName: projPath.lastComponentWithoutExtension,
                includeUserSchemes: includeUserSchemes
            )
            result += loadSchemes(
                at: wsPath,
                containerName: "workspace",
                includeUserSchemes: includeUserSchemes
            )

        case let .standaloneProject(projectURL):
            // Handle standalone project without workspace
            let projPath = Path(projectURL.path)
            result += loadSchemes(
                at: projPath,
                containerName: projPath.lastComponentWithoutExtension,
                includeUserSchemes: includeUserSchemes
            )
        }

        // 去重（同名 scheme 可能在多处出现，保留优先：workspace > project）
        var seen = Set<String>()
        let deduped = result.filter { info in
            if seen.contains(info.name) { return false }
            seen.insert(info.name)
            return true
        }

        return deduped.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func loadSchemes(
        at containerDir: Path,
        containerName: String,
        includeUserSchemes: Bool
    ) -> [XcodeScheme] {
        var schemes: [XcodeScheme] = []

        // 1) shared schemes
        let sharedDir = containerDir + "xcshareddata/xcschemes"
        if sharedDir.exists {
            for file in sharedDir.glob("*.xcscheme") {
                if let scheme = try? XCScheme(path: file) {
                    schemes.append(.init(name: scheme.name, path: file.url, container: containerName))
                }
            }
        }

        // 2) user schemes (optional)
        if includeUserSchemes {
            let usersDir = containerDir + "xcuserdata"
            if usersDir.exists {
                for file in (usersDir.glob("*.xcuserdatad/xcschemes/*.xcscheme")) ?? [] {
                    if let scheme = try? XCScheme(path: file) {
                        schemes.append(.init(name: scheme.name, path: file.url, container: containerName))
                    }
                }
            }
        }

        return schemes
    }

    private func resolveProjectPath(from location: String, workspacePath: Path) -> Path {
        if location.hasPrefix("absolute:") {
            let pathComponent = String(location.dropFirst(9)) // "absolute:".count = 9
            return Path(pathComponent)
        }

        // For group:, self:, container:, or plain relative paths
        let pathComponent = if location.contains(":") {
            String(location.split(separator: ":", maxSplits: 1).last ?? "")
        } else {
            location
        }

        return (workspacePath.parent() + Path(pathComponent)).normalize()
    }
}
