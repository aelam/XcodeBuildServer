//
//  BSPServerService.swift
//
//  Copyright © 2024 Wang Lun.
//

import BuildServerProtocol
import Foundation
import JSONRPCConnection
import Logger
import os

/// BSP 服务层 - 连接 BSP 协议和项目管理
/// 这是整个系统的核心服务，负责协调各个层次
public actor BSPServerService: ProjectStateObserver, BSPNotificationService {
    public let projectManagerProvider: ProjectManagerFactory
    private let jsonrpcConnection: JSONRPCConnection
    lazy var taskManager: BSPTaskManager = .init(notificationService: self)

    var projectManager: (any ProjectManager)?

    /// Service state tracking
    public enum ServiceState {
        case stopped
        case starting
        case running
        case stopping
    }

    private var serviceState: ServiceState = .stopped
    private let logger = Logger(subsystem: "BSPServerService", category: "BSPServer")

    public init(
        projectManagerProvider: ProjectManagerFactory,
        jsonrpcConnection: JSONRPCConnection
    ) {
        self.projectManagerProvider = projectManagerProvider
        self.jsonrpcConnection = jsonrpcConnection
    }

    // MARK: - Service Lifecycle

    /// 启动 BSP 服务
    /// 只启动网络服务，项目初始化由 build/initialize 请求触发
    public func start() async throws {
        guard serviceState == .stopped else {
            logger
                .warning("Service already started or starting, current state: \(String(describing: self.serviceState))")
            return
        }
        serviceState = .starting

        logger.info("Starting BSP Server Service for project")

        do {
            // 启动网络服务
            logger.info("Starting network service...")
            try await jsonrpcConnection.listen()

            serviceState = .running
            logger.info("BSP Server Service started successfully")
        } catch {
            serviceState = .stopped
            logger.error("Failed to start BSP Server Service: \(error)")
            throw error
        }
    }

    /// 停止 BSP 服务
    public func stop() async {
        guard serviceState == .running else {
            logger.warning("Service not running, current state: \(String(describing: self.serviceState))")
            return
        }
        serviceState = .stopping

        logger.info("Stopping BSP Server Service...")

        await jsonrpcConnection.close()

        serviceState = .stopped
        logger.info("BSP Server Service stopped")
    }
}

public extension BSPServerService {
    // MARK: - Task Management

    /// Get the task manager for this service
    func getTaskManager() -> BSPTaskManager {
        taskManager
    }

    // MARK: - BSPNotificationService Implementation

    func sendNotification(_ notification: ServerJSONRPCNotification<some Codable & Sendable>) async throws {
        try await jsonrpcConnection.send(notification: notification)
    }
}

// MARK: - Factory

public extension BSPServerService {
    /// 创建标准的 stdio BSP 服务
    static func createStdioService(projectManagerProvider: ProjectManagerFactory) -> BSPServerService {
        let transport = StdioJSONRPCConnectionTransport()
        let messageHandler = BSPMessageHandler()
        let connection = JSONRPCConnection(
            transport: transport,
            messageRegistry: bspRegistry,
            messageHandler: messageHandler
        )

        let service = BSPServerService(
            projectManagerProvider: projectManagerProvider,
            jsonrpcConnection: connection
        )

        // Set the service reference in the message handler
        messageHandler.setBSPServerService(service)

        return service
    }
}

// MARK: - ProjectStateObserver

public extension BSPServerService {
    func onProjectStateChanged(_ event: ProjectStateEvent) async {
        await notifyClientProjectStateChange(event)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func notifyClientProjectStateChange(_ event: ProjectStateEvent) async {
        do {
            switch event {
            case let .projectLoadStateChanged(_, to):
                switch to {
                case let .loading(projectPath):
                    try await sendShowMessageNotification(
                        "📂 Loading project: \(URL(fileURLWithPath: projectPath).lastPathComponent)...",
                        type: .info
                    )
                case let .loaded(projectInfo):
                    try await sendShowMessageNotification(
                        "✅ Project loaded: \(projectInfo.rootURL.lastPathComponent)",
                        type: .info
                    )
                case let .failed(error):
                    try await sendShowMessageNotification(
                        "❌ Failed to load project: \(error.localizedDescription)",
                        type: .error
                    )
                case .uninitialized:
                    break
                }
            case let .buildStarted(target):
                try await sendShowMessageNotification(
                    "🔨 Building \(target)...",
                    type: .info
                )
            case let .buildProgress(target, progress, message):
                let progressPercent = Int(progress * 100)
                try await sendShowMessageNotification(
                    "🔨 \(target): \(message) (\(progressPercent)%)",
                    type: .info
                )
            case let .buildCompleted(target, success, duration):
                let durationStr = String(format: "%.1fs", duration)
                try await sendShowMessageNotification(
                    success ? "✅ Build completed: \(target) (\(durationStr))" : "❌ Build failed: \(target)",
                    type: success ? .info : .error
                )
            case let .buildFailed(target, error):
                try await sendShowMessageNotification(
                    "❌ Build failed for \(target): \(error.localizedDescription)",
                    type: .error
                )
            case let .indexStateChanged(_, to):
                switch to {
                case let .indexing(progress, message):
                    let progressPercent = Int(progress * 100)
                    try await sendShowMessageNotification(
                        "🔍 Indexing: \(message) (\(progressPercent)%)",
                        type: .info
                    )
                case .completed:
                    try await sendShowMessageNotification(
                        "✅ Indexing completed",
                        type: .info
                    )
                case let .failed(error):
                    try await sendShowMessageNotification(
                        "❌ Indexing failed: \(error.localizedDescription)",
                        type: .error
                    )
                case .idle, .preparing:
                    break
                }
            }
        } catch {
            logger
                .warning(
                    "Failed to send notification for project state event \(String(describing: event)): \(String(describing: error))"
                )
        }
    }

    private func sendShowMessageNotification(
        _ message: String,
        type: LogMessageType
    ) async throws {
        try await sendNotification(ServerJSONRPCNotification(
            method: WindowShowMessageParams.method,
            params: WindowShowMessageParams(
                type: type,
                message: message
            )
        ))
    }

    // MARK: - Service Context API

    /// 获取当前项目管理器（供消息处理器使用）
    func getCurrentProjectManager() async -> (any ProjectManager)? {
        projectManager
    }

    /// 获取项目状态（供消息处理器使用）
    func getProjectState() async -> ProjectState? {
        await projectManager?.getProjectState()
    }

    /// 检查项目是否已初始化
    func isProjectInitialized() -> Bool {
        projectManager != nil
    }

    /// 获取项目根路径（如果已初始化）
    func getProjectRootURL() async -> URL? {
        await projectManager?.rootURL
    }
}
