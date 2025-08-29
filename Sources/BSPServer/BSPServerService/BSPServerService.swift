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
public final class BSPServerService: ProjectStateObserver, @unchecked Sendable {
    // MARK: - Components

    /// JSON-RPC 连接（协议层）
    private let jsonrpcConnection: JSONRPCConnection

    /// BSP 消息处理器
    private let messageHandler: BSPMessageHandler

    /// 项目管理器
    var projectManager: (any ProjectManager)?

    // MARK: - State

    public enum ServiceState: Sendable {
        case stopped
        case starting
        case running
        case stopping
    }

    private let serviceState = OSAllocatedUnfairLock(initialState: ServiceState.stopped)

    public var currentState: ServiceState {
        serviceState.withLock { $0 }
    }

    private var isRunning: Bool {
        serviceState.withLock { $0 == .running }
    }

    // MARK: - Initialization

    public init(
        transport: JSONRPCServerTransport,
        messageRegistry: MessageRegistry
    ) {
        self.messageHandler = BSPMessageHandler()

        // 创建 JSON-RPC 连接（协议层）
        self.jsonrpcConnection = JSONRPCConnection(
            transport: transport,
            messageRegistry: messageRegistry,
            messageHandler: messageHandler
        )

        // 设置消息处理器的服务引用
        messageHandler.setBSPServerService(self)
    }

    // MARK: - Service Lifecycle

    /// 启动 BSP 服务
    /// 只启动网络服务，项目初始化由 build/initialize 请求触发
    public func start() async throws {
        serviceState.withLock { state in
            guard state == .stopped else {
                logger.warning("Service already started or starting, current state: \(state)")
                return
            }
            state = .starting
        }

        logger.info("Starting BSP Server Service for project")

        do {
            // 启动网络服务
            logger.info("Starting network service...")
            try await jsonrpcConnection.listen()

            serviceState.withLock { $0 = .running }
            logger.info("BSP Server Service started successfully")
        } catch {
            serviceState.withLock { $0 = .stopped }
            logger.error("Failed to start BSP Server Service: \(error)")
            throw error
        }
    }

    /// 停止 BSP 服务
    public func stop() async {
        serviceState.withLock { state in
            guard state == .running else {
                logger.warning("Service not running, current state: \(state)")
                return
            }
            state = .stopping
        }

        logger.info("Stopping BSP Server Service...")

        await jsonrpcConnection.close()

        serviceState.withLock { $0 = .stopped }
        logger.info("BSP Server Service stopped")
    }
}

public extension BSPServerService {
    // MARK: - Notification Sending

    func sendNotification(_ notification: NotificationType) async throws {
        try await jsonrpcConnection.send(notification: notification)
    }
}

// MARK: - Factory

public extension BSPServerService {
    /// 创建标准的 stdio BSP 服务
    static func createStdioService() -> BSPServerService {
        let transport = StdioJSONRPCConnectionTransport()
        let registry = bspRegistry

        return BSPServerService(
            transport: transport,
            messageRegistry: registry
        )
    }

    /// 订阅项目管理器的状态变化
    func subscribeToProjectManager(_ projectManager: any ProjectManager) async {
        // 订阅项目状态
        await projectManager.addStateObserver(self)
        logger.debug("BSPServerService subscribed to project manager status changes")
    }

    /// 取消订阅项目管理器的状态变化
    func unsubscribeFromProjectManager(_ projectManager: any ProjectManager) async {
        await projectManager.removeStateObserver(self)
        logger.debug("BSPServerService unsubscribed from project manager status changes")
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
            logger.warning("Failed to send notification for project state event \(event): \(error)")
        }
    }

    private func sendShowMessageNotification(
        _ message: String,
        type: MessageType
    ) async throws {
        try await sendNotification(
            WindowShowMessageNotification(
                type: type,
                message: message
            )
        )
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
