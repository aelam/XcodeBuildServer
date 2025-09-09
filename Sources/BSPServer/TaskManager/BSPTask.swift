//
//  BSPTask.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation

/// Represents a BSP task with lifecycle management
public actor BSPTask {
    public let taskId: String
    public let originId: String?
    public let startTime: Date
    public let targets: [BSPBuildTargetIdentifier]

    public private(set) var currentMessage: String?
    public private(set) var progress: Double = 0.0
    public private(set) var status: StatusCode?
    public private(set) var finishTime: Date?

    private weak var manager: BSPTaskManager?

    init(
        taskId: String,
        originId: String?,
        message: String?,
        targets: [BSPBuildTargetIdentifier],
        manager: BSPTaskManager
    ) {
        self.taskId = taskId
        self.originId = originId
        self.currentMessage = message
        self.targets = targets
        self.manager = manager
        self.startTime = Date()
    }

    /// Update task progress
    public func updateProgress(progress: Double, message: String? = nil) async throws {
        self.progress = min(max(progress, 0.0), 1.0) // Clamp between 0.0 and 1.0
        if let message {
            self.currentMessage = message
        }

        guard let manager else { return }
        try await manager.updateTaskProgress(
            taskId: taskId,
            progress: self.progress,
            message: self.currentMessage
        )
    }

    /// Finish the task
    public func finish(status: StatusCode, message: String? = nil) async throws {
        self.status = status
        self.finishTime = Date()
        if let message {
            self.currentMessage = message
        }

        guard let manager else { return }
        try await manager.finishTask(
            taskId: taskId,
            status: status,
            message: self.currentMessage
        )
    }

    /// Mark task as successful
    public func succeed(message: String? = nil) async throws {
        try await finish(status: .ok, message: message)
    }

    /// Mark task as failed
    public func fail(message: String? = nil) async throws {
        try await finish(status: .error, message: message)
    }

    /// Cancel the task
    public func cancel(message: String? = nil) async throws {
        try await finish(status: .cancelled, message: message)
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
