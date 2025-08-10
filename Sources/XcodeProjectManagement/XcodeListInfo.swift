//
//  XcodeListInfo.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/10.
//

///
/// ```shell
/// xcodebuild -workspace Hello.xcworkspace -list -json
/// ```
///
/// ```json
///  {
///        "workspace" : {
///          "name" : "Hello",
///          "schemes" : [
///            "Hello (Hello project)",
///            "HelloUITests"
///          ]
///    }
///  }
///  ```
///
///  ```shell
///  xcodebuild -project Hello.xcodeproj -list -json
///  ```
///  ```json
///  {
///      "project": {
///          "configurations": ["Debug", "Release"],
///          "name": "Hello",
///          "schemes": ["Hello", "HelloUITests"],
///          "targets": ["Hello", "HelloTests", "HelloUITests"]
///  }
/// }
/// ```
///

public struct XcodeListInfo: Decodable, Sendable {
    public let kind: Kind

    public struct XcodeListWorkspace: Codable, Sendable {
        public let name: String
        public let schemes: [String]
    }

    public struct XcodeListProject: Codable, Sendable {
        public let name: String
        public let configurations: [String]
        public let schemes: [String]
        public let targets: [String]
    }

    public enum Kind: Decodable, Sendable {
        case workspace(XcodeListWorkspace)
        case project(XcodeListProject)
    }

    enum CodingKeys: String, CodingKey {
        case workspace, project
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let workspace = try container.decodeIfPresent(XcodeListWorkspace.self, forKey: .workspace) {
            self.kind = .workspace(workspace)
        } else if let project = try container.decodeIfPresent(XcodeListProject.self, forKey: .project) {
            self.kind = .project(project)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected either 'workspace' or 'project' at root"
                )
            )
        }
    }
}

extension XcodeListInfo {
    var schemes: [String] {
        switch kind {
        case let .workspace(workspace):
            workspace.schemes
        case let .project(project):
            project.schemes
        }
    }
}
