//
//  XcodeContainerParser.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

/// Parser for Xcode workspace and project containers to extract scheme folder URLs
public struct XcodeContainerParser: Sendable {
    public init() {}

    /// Get all container URLs from a container URL (workspace or project)
    public func getContainerURLs(from containerURL: URL) -> [URL] {
        let isWorkspace = containerURL.pathExtension == "xcworkspace"
        return parseContainerURLs(containerURL: containerURL, isWorkspace: isWorkspace)
    }

    /// Parse container URLs to extract project references
    private func parseContainerURLs(containerURL: URL, isWorkspace: Bool) -> [URL] {
        if isWorkspace {
            // For workspace: include workspace itself + referenced projects
            let projectURLs = getProjectURLs(workspaceURL: containerURL)
            return [containerURL] + projectURLs
        } else {
            // For project: only return the project itself (no duplication)
            return [containerURL]
        }
    }

    /// Get project URLs from workspace contents
    private func getProjectURLs(workspaceURL: URL) -> [URL] {
        guard let contents = try? Data(
            contentsOf: workspaceURL.appendingPathComponent("contents.xcworkspacedata")
        ),
            let xml = try? XMLDocument(data: contents) else {
            return []
        }

        let fileRefNodes = xml.rootElement()?.elements(forName: "FileRef")
        return fileRefNodes?.compactMap { node in
            parseFileRefLocation(node: node, containerURL: workspaceURL)
        } ?? []
    }

    /// Parse FileRef location attribute into URL
    private func parseFileRefLocation(node: XMLElement, containerURL: URL) -> URL? {
        guard let location = node.attribute(forName: "location")?.stringValue else {
            return nil
        }

        // Parse different location formats:
        // - group:path/to/project.xcodeproj (relative to workspace)
        // - absolute:/absolute/path/to/project.xcodeproj (absolute path)
        // - container:path/to/project.xcodeproj (relative to container)

        if location.hasPrefix("group:") {
            let path = String(location.dropFirst(6)) // Remove "group:" prefix
            return containerURL.deletingLastPathComponent().appendingPathComponent(path)
        } else if location.hasPrefix("absolute:") {
            let path = String(location.dropFirst(9)) // Remove "absolute:" prefix
            return URL(fileURLWithPath: path)
        } else if location.hasPrefix("container:") {
            let path = String(location.dropFirst(10)) // Remove "container:" prefix
            return containerURL.deletingLastPathComponent().appendingPathComponent(path)
        } else if location.hasPrefix("self:") {
            // Self-reference to the workspace itself
            return containerURL
        }

        // Fallback: treat as relative path
        return containerURL.deletingLastPathComponent().appendingPathComponent(location)
    }
}

/// Extension to convert container URLs to scheme folder URLs
public extension XcodeContainerParser {
    /// Convert container URLs to their corresponding scheme folder URLs
    func getSchemeFolderURLs(from containerURLs: [URL]) -> [URL] {
        var allContainerURLs: [URL] = []

        for containerURL in containerURLs {
            let containerSchemeURLs = getContainerURLs(from: containerURL)
            allContainerURLs.append(contentsOf: containerSchemeURLs)
        }

        return allContainerURLs.flatMap { url in
            [
                url.appending(component: "xcshareddata").appending(component: "xcschemes"),
                url.appending(component: "xcuserdata").appending(component: "xcschemes")
            ]
        }
    }

    /// Get scheme folder URLs from a single container URL with scheme folder expansion
    func getSchemeFolderURLs(from containerURL: URL) -> [URL] {
        let containerURLs = getContainerURLs(from: containerURL)
        return containerURLs.flatMap { url in
            [
                url.appending(component: "xcshareddata").appending(component: "xcschemes"),
                url.appending(component: "xcuserdata").appending(component: "xcschemes")
            ]
        }
    }

    /// Get scheme file URLs directly from a container URL
    func getSchemeFileURLs(from containerURL: URL) -> [URL] {
        let schemeFolderURLs = getSchemeFolderURLs(from: containerURL)
        return schemeFolderURLs.flatMap { findSchemeFiles(in: $0) }
    }

    /// Find scheme files in a container URL (workspace or project)
    func findSchemeFiles(in schemeFolderURL: URL) -> [URL] {
        var schemeFiles: [URL] = []

        if FileManager.default.fileExists(atPath: schemeFolderURL.path) {
            do {
                let schemes = try FileManager.default
                    .contentsOfDirectory(at: schemeFolderURL, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "xcscheme" }
                schemeFiles += schemes
            } catch {
                logger.debug("Failed to read shared schemes: \(error)")
            }
        }

        return schemeFiles
    }
}
