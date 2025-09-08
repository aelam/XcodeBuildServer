import Foundation

struct CompileReport: Codable, Hashable, Sendable {
    let target: BSPBuildTargetIdentifier
    let originId: String?
    let errors: Int
    let warnings: Int
    let time: TimeInterval?
    let noOp: Bool?
}
