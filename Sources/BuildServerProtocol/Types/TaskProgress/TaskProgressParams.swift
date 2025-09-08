import Foundation

struct TaskProgressParams: Codable, Sendable {
    /** The id of the task. */
    let taskId: String
    let originId: String?
    let eventTime: TimeInterval?
    let message: String?
    let progress: Double?
    let unit: String?
    let dataKind: TaskProgressDataKind?
    let data: Data?
}

typealias TaskProgressDataKind = String
