import Foundation

struct TaskFinishParams: Codable, Sendable {
    let taskId: String
    let originId: String?
    let eventTime: TimeInterval?
    let message: String?
    let status: StatusCode
}

typealias TaskFinishDataKind = String

extension TaskFinishDataKind {
    static let CompileReport: TaskFinishDataKind = "compile-report"
    static let TestFinish: TaskFinishDataKind = "test-finish"
    static let TestReport: TaskFinishDataKind = "test-report"
}
