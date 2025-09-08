// //
// //  BuildTaskProgressNotification.swift
// //  XcodeBuildServer
// //
// //  Created by ST22956 on 2024/11/17.
// //

// import BuildServerProtocol
// import JSONRPCConnection
// import Logger

// public struct BuildTaskProgressNotification: ServerJSONRPCNotificationType {
//     public static func method() -> String {
//         "build/taskProgress"
//     }

//     public struct Params: Codable, Sendable {
//         /// The build target for which the task is started
//         public let target: BSPBuildTargetIdentifier
//         /// An optional request id to know the origin of this report.
//         public let originId: String?

//         public init(target: BSPBuildTargetIdentifier, originId: String? = nil) {
//             self.target = target
//             self.originId = originId
//         }
//     }

//     public let params: Params
//     public init(params: Params) {
//         self.params = params
//     }
// }
