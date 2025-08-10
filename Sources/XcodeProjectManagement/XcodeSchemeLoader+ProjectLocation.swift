//
//  XcodeSchemeLoader+ProjectLocation.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/10.
//

extension XcodeSchemeLoader {
    func loadSchemes(
        from projectLocation: XcodeProjectLocation,
        filterBy schemeNames: [String] = []
    ) throws -> [XcodeSchemeInfo] {
        switch projectLocation {
        case let .explicitWorkspace(workspaceURL):
            try loadSchemes(fromWorkspace: workspaceURL, filterBy: schemeNames)
        case let .implicitWorkspace(projectURL: projectURL, workspaceURL: _):
            try loadSchemes(fromProject: projectURL, filterBy: schemeNames)
        }
    }
}
