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
}

public typealias TaskProgressDataKind = String
