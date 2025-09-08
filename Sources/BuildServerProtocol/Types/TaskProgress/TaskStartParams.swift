import Foundation

struct TaskStartParams: Codable, Sendable {
    /** The task id. */
    let taskId: String
    let originId: String?
    let eventTime: TimeInterval?
    let message: String?
    let dataKind: TaskStartDataKind?
    let data: Data?
}

typealias TaskStartDataKind = String

extension TaskStartDataKind {
    static let compileTask: TaskStartDataKind = "compile-task"
    static let testStart: TaskStartDataKind = "test-start"
    static let testTask: TaskStartDataKind = "test-task"
}
