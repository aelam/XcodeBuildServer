//
//  XcodeBSPConfiguration.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeProjectManagement

public struct XcodeBSPConfiguration: Codable, Sendable {
    public let workspace: String?
    public let project: String?
    public let scheme: String?
    public let configuration: String?

    public static let defaultConfiguration = "Debug"

    public init(workspace: String? = nil, project: String? = nil, scheme: String? = nil, configuration: String? = nil) {
        self.workspace = workspace
        self.project = project
        self.scheme = scheme
        self.configuration = configuration
    }

    // Convert to XcodeProjectReference for project management
    public var projectReference: XcodeProjectReference {
        XcodeProjectReference(
            workspace: workspace,
            project: project,
            scheme: scheme,
            configuration: configuration
        )
    }
}
