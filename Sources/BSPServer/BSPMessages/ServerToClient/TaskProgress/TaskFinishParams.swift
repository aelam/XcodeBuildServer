import BuildServerProtocol
import Foundation

public struct TaskFinishParams: Codable, Sendable {
    public static let method = "build/taskFinish"

    public let taskId: String
    public let originId: String?
    public let eventTime: TimeInterval?
    public let message: String?
    public let status: StatusCode
}

public typealias TaskFinishDataKind = String

public extension TaskFinishDataKind {
    static let CompileReport: TaskFinishDataKind = "compile-report"
    static let TestFinish: TaskFinishDataKind = "test-finish"
    static let TestReport: TaskFinishDataKind = "test-report"
}
