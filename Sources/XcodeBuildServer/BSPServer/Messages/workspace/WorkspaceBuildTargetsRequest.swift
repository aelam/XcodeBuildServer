//
//  WorkspaceBuildTargetsRequest.swift
//
//  Copyright © 2024 Wang Lun.
//

/**
 export interface BuildTargetTag {
   // ...

   /** This is a target of a dependency from the project the user opened, eg. a target that builds a SwiftPM dependency. */
   export const Dependency = "dependency";

   /** This target only exists to provide compiler arguments for SourceKit-LSP can't be built standalone.
    *
    * For example, a SwiftPM package manifest is in a non-buildable target. **/
   export const NotBuildable = "not-buildable";
 }

 */

public struct WorkspaceBuildTargetsRequest: RequestType, @unchecked Sendable {
    public static var method: String { "workspace/buildTargets" }

    public struct Params: Codable {
        public var targets: [String]
    }

    public func handle(
        _: MessageHandler,
        id _: RequestID
    ) async -> ResponseType? {
        fatalError()
    }
}
