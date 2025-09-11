//
//  BSPTask.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation

/// Represents a BSP task with lifecycle management
public final class BSPTask: @unchecked Sendable {
    public let taskId: String
    public let originId: String?
    public let startTime: Date

    public private(set) var currentMessage: String?
    public private(set) var progress: Double = 0.0
    public private(set) var status: StatusCode?
    public private(set) var finishTime: Date?

    init(
        taskId: String,
        originId: String?,
        message: String?,
    ) {
        self.taskId = taskId
        self.originId = originId
        self.currentMessage = message
        self.startTime = Date()
    }

    /// Update task progress (internal state only)
    public func updateProgress(progress: Double, message: String? = nil) {
        self.progress = min(max(progress, 0.0), 1.0) // Clamp between 0.0 and 1.0
        if let message {
            self.currentMessage = message
        }
    }

    /// Finish the task (internal state only)
    public func finish(status: StatusCode, message: String? = nil) {
        self.status = status
        self.finishTime = Date()
        if let message {
            self.currentMessage = message
        }
    }

    /// Mark task as successful (internal state only)
    public func succeed(message: String? = nil) {
        finish(status: .ok, message: message)
    }

    /// Mark task as failed (internal state only)
    public func fail(message: String? = nil) {
        finish(status: .error, message: message)
    }

    /// Cancel the task (internal state only)
    public func cancel(message: String? = nil) {
        finish(status: .cancelled, message: message)
    }

    /// Check if task is finished
    public var isFinished: Bool {
        status != nil
    }

    /// Get task duration
    public var duration: TimeInterval {
        let endTime = finishTime ?? Date()
        return endTime.timeIntervalSince(startTime)
    }
}
