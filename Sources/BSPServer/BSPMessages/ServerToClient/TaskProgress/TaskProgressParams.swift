import Foundation

public struct TaskProgressParams: Codable, Sendable {
    public static let method = "build/taskProgress"

    /** The id of the task. */
    public let taskId: String
    public let originId: String?
    public let eventTime: TimeInterval?
    public let message: String?
    public let progress: Double?
    public let unit: String?
    public let dataKind: TaskProgressDataKind?
    public let data: Data?

    public init(
        taskId: String,
        originId: String? = nil,
        eventTime: TimeInterval? = nil,
        message: String? = nil,
        progress: Double? = nil,
        unit: String? = nil,
        dataKind: TaskProgressDataKind? = nil,
        data: Data? = nil
    ) {
        self.taskId = taskId
        self.originId = originId
        self.eventTime = eventTime
        self.message = message
        self.progress = progress
        self.unit = unit
        self.dataKind = dataKind
        self.data = data
    }
}

public typealias TaskProgressDataKind = String
