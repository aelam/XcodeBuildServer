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
                isInWorkspace: true,
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
                        isInWorkspace: false,
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
                isInWorkspace: false,
                includeUserSchemes: includeUserSchemes
            )
            result += loadSchemes(
                at: wsPath,
                containerName: "workspace",
                isInWorkspace: true,
                includeUserSchemes: includeUserSchemes
            )

        case let .standaloneProject(projectURL):
            // Handle standalone project without workspace
            let projPath = Path(projectURL.path)
            result += loadSchemes(
                at: projPath,
                containerName: projPath.lastComponentWithoutExtension,
                isInWorkspace: false,
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

        return deduped.sorted { lhs, rhs in
            // First sort by orderHint if available
            if let lhsOrder = lhs.orderHint, let rhsOrder = rhs.orderHint {
                return lhsOrder < rhsOrder
            } else if lhs.orderHint != nil {
                return true // Schemes with orderHint come first
            } else if rhs.orderHint != nil {
                return false
            }
            // Fall back to alphabetical sorting
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func loadSchemes(
        at containerDir: Path,
        containerName: String,
        isInWorkspace: Bool,
        includeUserSchemes: Bool
    ) -> [XcodeScheme] {
        var schemes: [XcodeScheme] = []

        // Load scheme ordering from xcschememanagement.plist if available
        var schemeOrderMap: [String: Int] = [:]
        if includeUserSchemes {
            let usersDir = containerDir + "xcuserdata"
            if usersDir.exists {
                for managementFile in usersDir.glob("*.xcuserdatad/xcschemes/xcschememanagement.plist") {
                    schemeOrderMap = loadSchemeOrderMap(from: managementFile)
                    break // Use first found management file
                }
            }
        }

        // 1) shared schemes
        let sharedDir = containerDir + "xcshareddata/xcschemes"
        if sharedDir.exists {
            for file in sharedDir.glob("*.xcscheme") {
                if let scheme = try? XCScheme(path: file) {
                    var xcodeScheme = XcodeScheme(
                        xcscheme: scheme,
                        isInWorkspace: isInWorkspace,
                        isUserScheme: false,
                        projectURL: containerDir.url,
                        path: file.url
                    )

                    // Apply ordering from xcschememanagement.plist
                    let sharedKey = "\(scheme.name).xcscheme_^#shared#^_"
                    if let order = schemeOrderMap[sharedKey] {
                        xcodeScheme.orderHint = order
                    }

                    schemes.append(xcodeScheme)
                }
            }
        }

        // 2) user schemes (optional)
        if includeUserSchemes {
            let usersDir = containerDir + "xcuserdata"
            if usersDir.exists {
                for file in usersDir.glob("*.xcuserdatad/xcschemes/*.xcscheme") {
                    if let scheme = try? XCScheme(path: file) {
                        var xcodeScheme = XcodeScheme(
                            xcscheme: scheme,
                            isInWorkspace: isInWorkspace,
                            isUserScheme: true,
                            projectURL: containerDir.url,
                            path: file.url
                        )

                        // Apply ordering from xcschememanagement.plist
                        let userKey = "\(scheme.name).xcscheme"
                        if let order = schemeOrderMap[userKey] {
                            xcodeScheme.orderHint = order
                        }

                        schemes.append(xcodeScheme)
                    }
                }
            }
        }

        return schemes
    }

    private func loadSchemeOrderMap(from plistPath: Path) -> [String: Int] {
        guard let plistData = try? Data(contentsOf: plistPath.url),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let schemeUserState = plist["SchemeUserState"] as? [String: Any] else {
            return [:]
        }

        var orderMap: [String: Int] = [:]
        for (schemeName, schemeInfo) in schemeUserState {
            if let info = schemeInfo as? [String: Any],
               let orderHint = info["orderHint"] as? Int {
                orderMap[schemeName] = orderHint
            }
        }
        return orderMap
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
