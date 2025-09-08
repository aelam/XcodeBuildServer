import Foundation

struct TestReport: Codable, Hashable, Sendable {
    let originId: String?
    let target: BSPBuildTargetIdentifier
    let passed: Int
    let failed: Int
    let ignored: Int
    let cancelled: Int
    let skipped: Int
    let time: TimeInterval?
}
