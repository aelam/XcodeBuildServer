import BuildServerProtocol
import Foundation

public struct TaskFinishParams: Codable, Sendable {
    public static let method = "build/taskFinish"

    public let taskId: String
    public let originId: String?
    public let eventTime: TimeInterval?
    public let message: String?
    public let status: StatusCode
    public let dataKind: TaskFinishDataKind?
    public let data: Data?

    public init(
        taskId: String,
        originId: String? = nil,
        eventTime: TimeInterval? = nil,
        message: String? = nil,
        status: StatusCode,
        dataKind: TaskFinishDataKind? = nil,
        data: Data? = nil
    ) {
        self.taskId = taskId
        self.originId = originId
        self.eventTime = eventTime
        self.message = message
        self.status = status
        self.dataKind = dataKind
        self.data = data
    }
}

public typealias TaskFinishDataKind = String

public extension TaskFinishDataKind {
    static let CompileReport: TaskFinishDataKind = "compile-report"
    static let TestFinish: TaskFinishDataKind = "test-finish"
    static let TestReport: TaskFinishDataKind = "test-report"
}
