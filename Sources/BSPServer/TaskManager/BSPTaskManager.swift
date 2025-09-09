//
//  BSPTaskManager.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation
import JSONRPCConnection
import Logger

/// Manages BSP task lifecycle including taskStart, taskProgress, and taskFinish notifications
public actor BSPTaskManager {
    private var activeTasks: [String: BSPTask] = [:]
    private var taskCounter: Int = 0
    private weak var notificationSender: BSPNotificationSender?

    public init(notificationSender: BSPNotificationSender) {
        self.notificationSender = notificationSender
    }

    /// Generate a unique task ID
    private func generateTaskId() -> String {
        taskCounter += 1
        return "task-\(taskCounter)-\(Date().timeIntervalSince1970)"
    }

    /// Start a new task
    public func startTask(
        originId: String? = nil,
        message: String,
        targets: [BSPBuildTargetIdentifier] = []
    ) async throws -> BSPTask {
        let taskId = generateTaskId()
        let task = BSPTask(
            taskId: taskId,
            originId: originId,
            message: message,
            targets: targets,
            manager: self
        )

        activeTasks[taskId] = task

        // Send taskStart notification
        try await sendTaskStartNotification(task: task)

        logger.debug("Started task: \(taskId) - \(message)")
        return task
    }

    /// Update task progress
    func updateTaskProgress(
        taskId: String,
        progress: Double,
        message: String? = nil
    ) async throws {
        guard let task = activeTasks[taskId] else {
            logger.warning("Attempted to update progress for unknown task: \(taskId)")
            return
        }

        try await task.updateProgress(progress: progress, message: message)

        // Send taskProgress notification
        try await sendTaskProgressNotification(task: task)

        logger.debug("Updated task progress: \(taskId) - \(progress * 100)%")
    }

    /// Finish a task
    func finishTask(
        taskId: String,
        status: StatusCode,
        message: String? = nil
    ) async throws {
        guard let task = activeTasks[taskId] else {
            logger.warning("Attempted to finish unknown task: \(taskId)")
            return
        }

        try await task.finish(status: status, message: message)
        activeTasks.removeValue(forKey: taskId)

        // Send taskFinish notification
        try await sendTaskFinishNotification(task: task)

        logger.debug("Finished task: \(taskId) - \(status)")
    }

    /// Get active task by ID
    public func getTask(taskId: String) -> BSPTask? {
        activeTasks[taskId]
    }

    /// Get all active tasks
    public func getActiveTasks() -> [BSPTask] {
        Array(activeTasks.values)
    }

    /// Cancel all active tasks
    public func cancelAllTasks() async throws {
        for task in activeTasks.values {
            try await finishTask(
                taskId: task.taskId,
                status: .cancelled,
                message: "Task cancelled"
            )
        }
    }

    // MARK: - Notification Sending

    private func sendTaskStartNotification(task: BSPTask) async throws {
        let params = await TaskStartParams(
            taskId: task.taskId,
            originId: task.originId,
            eventTime: task.startTime.timeIntervalSince1970,
            message: task.currentMessage
        )

        let notification = ServerJSONRPCNotification(
            method: "build/taskStart",
            params: params
        )

        try await notificationSender?.sendNotification(notification)
    }

    private func sendTaskProgressNotification(task: BSPTask) async throws {
        let params = await TaskProgressParams(
            taskId: task.taskId,
            originId: task.originId,
            eventTime: Date().timeIntervalSince1970,
            message: task.currentMessage,
            progress: task.progress,
            unit: nil,
            dataKind: nil,
            data: nil
        )

        let notification = ServerJSONRPCNotification(
            method: "build/taskProgress",
            params: params
        )

        try await notificationSender?.sendNotification(notification)
    }

    private func sendTaskFinishNotification(task: BSPTask) async throws {
        let params = await TaskFinishParams(
            taskId: task.taskId,
            originId: task.originId,
            eventTime: task.finishTime?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            message: task.currentMessage,
            status: task.status ?? .error
        )

        let notification = ServerJSONRPCNotification(
            method: "build/taskFinish",
            params: params
        )

        try await notificationSender?.sendNotification(notification)
    }

    // MARK: - Direct Notification Methods (for non-blocking builds)

    func sendTaskStartNotification(
        taskId: String,
        originId: String?,
        message: String,
        targets: [BSPBuildTargetIdentifier]
    ) async throws {
        let params = TaskStartParams(
            taskId: taskId,
            originId: originId,
            eventTime: Date().timeIntervalSince1970,
            message: message
        )

        let notification = ServerJSONRPCNotification(
            method: "build/taskStart",
            params: params
        )

        try await notificationSender?.sendNotification(notification)
    }

    func sendTaskProgressNotification(
        taskId: String,
        progress: Double,
        message: String?
    ) async throws {
        let params = TaskProgressParams(
            taskId: taskId,
            originId: nil,
            eventTime: Date().timeIntervalSince1970,
            message: message,
            progress: progress,
            unit: nil,
            dataKind: nil,
            data: nil
        )

        let notification = ServerJSONRPCNotification(
            method: "build/taskProgress",
            params: params
        )

        try await notificationSender?.sendNotification(notification)
    }

    func sendTaskFinishNotification(
        taskId: String,
        status: StatusCode,
        message: String?
    ) async throws {
        let params = TaskFinishParams(
            taskId: taskId,
            originId: nil,
            eventTime: Date().timeIntervalSince1970,
            message: message,
            status: status
        )

        let notification = ServerJSONRPCNotification(
            method: "build/taskFinish",
            params: params
        )

        try await notificationSender?.sendNotification(notification)
    }
}

/// Protocol for sending BSP notifications
public protocol BSPNotificationSender: AnyObject, Sendable {
    func sendNotification(_ notification: ServerJSONRPCNotification<some Codable & Sendable>) async throws
}

/// Default implementation using JSONRPCConnection
public final class BSPNotificationSenderImpl: BSPNotificationSender, @unchecked Sendable {
    private let connection: JSONRPCConnection

    public init(connection: JSONRPCConnection) {
        self.connection = connection
    }

    public func sendNotification(_ notification: ServerJSONRPCNotification<some Codable & Sendable>) async throws {
        try await connection.send(notification: notification)
    }
}
