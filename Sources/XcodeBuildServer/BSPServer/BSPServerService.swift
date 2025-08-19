//
//  BSPServerService.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import JSONRPCConnection
import Logger
import os
import XcodeProjectManagement

/// BSP 服务层 - 连接 BSP 协议和项目管理
/// 这是整个系统的核心服务，负责协调各个层次
public final class BSPServerService: ProjectStateObserver {
    // MARK: - Components

    /// JSON-RPC 连接（协议层）
    private let jsonrpcConnection: JSONRPCConnection

    /// BSP 消息处理器
    private let messageHandler: XcodeBSPMessageHandler

    /// 构建服务器上下文 (包含项目管理器)
    private let buildServerContext: BuildServerContext

    // MARK: - State

    private let isRunningState = OSAllocatedUnfairLock(initialState: false)

    private var isRunning: Bool {
        get {
            isRunningState.withLock { $0 }
        }
        set {
            isRunningState.withLock { $0 = newValue }
        }
    }

    // MARK: - Initialization

    public init(
        transport: JSONRPCServerTransport,
        messageRegistry: MessageRegistry
    ) {
        // 创建构建服务器上下文
        self.buildServerContext = BuildServerContext()

        // 创建消息处理器（BSP 层）
        self.messageHandler = XcodeBSPMessageHandler()

        // 创建 JSON-RPC 连接（协议层）
        self.jsonrpcConnection = JSONRPCConnection(
            transport: transport,
            messageRegistry: messageRegistry,
            messageHandler: messageHandler
        )

        // 设置消息处理器的服务引用
        messageHandler.setBSPServerService(self)

        // 设置项目管理器订阅
        self.setupProjectManagerSubscription()
    }

    // MARK: - Service Lifecycle

    /// 启动 BSP 服务
    public func start() async throws {
        guard !isRunning else { return }

        logger.info("Starting BSP Server Service...")
        isRunning = true

        try await jsonrpcConnection.listen()
    }

    /// 停止 BSP 服务
    public func stop() async {
        guard isRunning else { return }

        logger.info("Stopping BSP Server Service...")
        isRunning = false

        await jsonrpcConnection.close()
    }

    // MARK: - Private Setup

    private func setupProjectManagerSubscription() {
        // 设置项目管理器创建回调，当项目管理器创建时自动订阅状态变化
        Task {
            await buildServerContext.setProjectManagerCreatedCallback { [weak self] projectManager in
                await self?.subscribeToProjectManager(projectManager)
            }
        }
    }

    // MARK: - Notification Sending

    /// 发送通知到客户端
    public func sendNotification(_ notification: NotificationType) async throws {
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
    func subscribeToProjectManager(_ projectManager: XcodeProjectManager) async {
        // 订阅项目状态
        await projectManager.addStateObserver(self)
        logger.debug("BSPServerService subscribed to project manager status changes")
    }

    /// 取消订阅项目管理器的状态变化
    func unsubscribeFromProjectManager(_ projectManager: XcodeProjectManager) async {
        await projectManager.removeStateObserver(self)
        logger.debug("BSPServerService unsubscribed from project manager status changes")
    }
}

// MARK: - ProjectStateObserver

public extension BSPServerService {
    /// 响应项目状态管理器的状态变化
    func onProjectStateChanged(_ event: ProjectStateEvent) async {
        await convertProjectStateToNotification(event)
    }

    /// 将项目状态事件转换为 BSP 通知
    private func convertProjectStateToNotification(_ event: ProjectStateEvent) async {
        do {
            switch event {
            case let .projectLoadStateChanged(_, to):
                switch to {
                case let .loading(projectPath):
                    try await messageHandler.sendNotification(
                        WindowShowMessageNotification(
                            type: .info,
                            message: "📂 Loading project: \(URL(fileURLWithPath: projectPath).lastPathComponent)..."
                        )
                    )
                case let .loaded(projectInfo):
                    try await messageHandler.sendNotification(
                        WindowShowMessageNotification(
                            type: .info,
                            message: "✅ Project loaded: \(projectInfo.rootURL.lastPathComponent)"
                        )
                    )
                case let .failed(error):
                    try await messageHandler.sendNotification(
                        WindowShowMessageNotification(
                            type: .error,
                            message: "❌ Failed to load project: \(error.localizedDescription)"
                        )
                    )
                case .uninitialized:
                    break
                }

            case let .buildStarted(target):
                try await messageHandler.sendNotification(
                    WindowShowMessageNotification(
                        type: .info,
                        message: "🔨 Building \(target)..."
                    )
                )

            case let .buildProgress(target, progress, message):
                let progressPercent = Int(progress * 100)
                try await messageHandler.sendNotification(
                    WindowShowMessageNotification(
                        type: .info,
                        message: "🔨 \(target): \(message) (\(progressPercent)%)"
                    )
                )

            case let .buildCompleted(target, success, duration):
                let durationStr = String(format: "%.1fs", duration)
                try await messageHandler.sendNotification(
                    WindowShowMessageNotification(
                        type: success ? .info : .error,
                        message: success ? "✅ Build completed: \(target) (\(durationStr))" : "❌ Build failed: \(target)"
                    )
                )

            case let .buildFailed(target, error):
                try await messageHandler.sendNotification(
                    WindowShowMessageNotification(
                        type: .error,
                        message: "❌ Build failed for \(target): \(error.localizedDescription)"
                    )
                )

            case let .indexStateChanged(_, to):
                switch to {
                case let .indexing(progress, message):
                    let progressPercent = Int(progress * 100)
                    try await messageHandler.sendNotification(
                        WindowShowMessageNotification(
                            type: .info,
                            message: "🔍 Indexing: \(message) (\(progressPercent)%)"
                        )
                    )
                case .completed:
                    try await messageHandler.sendNotification(
                        WindowShowMessageNotification(
                            type: .info,
                            message: "✅ Indexing completed"
                        )
                    )
                case let .failed(error):
                    try await messageHandler.sendNotification(
                        WindowShowMessageNotification(
                            type: .error,
                            message: "❌ Indexing failed: \(error.localizedDescription)"
                        )
                    )
                case .idle, .preparing:
                    break
                }
            }
        } catch {
            logger.error("Failed to send notification for project state event \(event): \(error)")
        }
    }

    // MARK: - Service Context API

    /// 获取构建服务器上下文
    func getBuildServerContext() -> BuildServerContext {
        buildServerContext
    }

    /// 获取当前项目管理器（供消息处理器使用）
    func getCurrentProjectManager() async -> XcodeProjectManager? {
        try? await buildServerContext.getProjectManager()
    }

    /// 获取项目状态（供消息处理器使用）
    func getProjectState() async -> ProjectState? {
        guard let projectManager = await getCurrentProjectManager() else {
            return nil
        }
        return await projectManager.getProjectState()
    }

    /// 获取编译参数（供消息处理器使用）
    func getCompileArguments(targetIdentifier: BuildTargetIdentifier, fileURI: String) async throws -> [String] {
        let context = getBuildServerContext()
        return try await context.getCompileArguments(targetIdentifier: targetIdentifier, fileURI: fileURI)
    }

    /// 获取工作目录（供消息处理器使用）
    func getWorkingDirectory() async throws -> String {
        let context = getBuildServerContext()
        return try await context.getWorkingDirectory() ?? ""
    }

    /// 获取索引存储 URL（供消息处理器使用）
    func getIndexStoreURL() async throws -> URL {
        let context = getBuildServerContext()
        return try await context.getIndexStoreURL()
    }

    /// 获取索引数据库 URL（供消息处理器使用）
    func getIndexDatabaseURL() async throws -> URL {
        let context = getBuildServerContext()
        return try await context.getIndexDatabaseURL()
    }

    /// 获取派生数据路径（供消息处理器使用）
    func getDerivedDataPath() async throws -> URL {
        let context = getBuildServerContext()
        return try await context.getDerivedDataPath()
    }

    /// 为索引构建目标（供消息处理器使用）
    func buildTargetForIndex(targets: [BuildTargetIdentifier]) async throws {
        let context = getBuildServerContext()
        try await context.buildTargetForIndex(targets: targets)
    }

    /// 加载项目（供消息处理器使用）
    func loadProject(rootURL: URL) async throws {
        let context = getBuildServerContext()
        try await context.loadProject(rootURL: rootURL)
    }
}
