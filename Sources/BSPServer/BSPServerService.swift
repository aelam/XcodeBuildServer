//
//  BSPServerService.swift
//
//  Copyright © 2024 Wang Lun.
//

import Core
import Foundation
import JSONRPCConnection
import Logger
import os
import SwiftPMProjectProvider
import XcodeProjectManagement

/// BSP 服务层 - 连接 BSP 协议和项目管理
/// 这是整个系统的核心服务，负责协调各个层次
public final class BSPServerService: ProjectStateObserver, @unchecked Sendable {
    // MARK: - Components

    /// JSON-RPC 连接（协议层）
    private let jsonrpcConnection: JSONRPCConnection

    /// BSP 消息处理器
    private let messageHandler: XcodeBSPMessageHandler

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

    // MARK: - Project Management

    /// 初始化项目（供 BuildInitializeRequest 调用）
    public func initializeProject(rootURL: URL) async throws {
        // 如果项目已经初始化，直接返回
        if projectManager != nil {
            return
        }

        logger.info("Initializing project...")

        let projectManager = try await ProjectProviderRegistry.createFactory().createProjectManager(
            rootURL: rootURL
        )
        // 检测项目类型
        logger.info("Detected project type: " + projectManager.projectType)

        try await projectManager.initialize()
        let projectInfo = try await projectManager.resolveProjectInfo()

        // 订阅状态变化
        await subscribeToProjectManager(projectManager)

        self.projectManager = projectManager
        logger.info("Project loaded successfully: \(projectInfo.rootURL.lastPathComponent)")
    }

    // MARK: - Notification Sending

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
        try await messageHandler.sendNotification(
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

// MARK: - BSP Protocol Adapters

extension BSPServerService {
    /// 获取编译参数（BSP 协议适配）
    func getCompileArguments(targetIdentifier: BuildTargetIdentifier, fileURI: String) async throws -> [String] {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project not initialized")
        }

        logger.debug("Getting compile arguments for target: \(targetIdentifier.uri.stringValue), file: \(fileURI)")

        return try await projectManager.getCompileArguments(
            targetIdentifier: targetIdentifier.uri.stringValue,
            fileURI: fileURI
        )
    }

    /// 获取工作目录（BSP 协议适配）
    func getWorkingDirectory() async throws -> String? {
        await projectManager?.rootURL.path
    }

    /// 创建构建目标列表（BSP 协议适配）
    func createBuildTargets() async throws -> [BuildTarget] {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project manager not initialized")
        }

        // 如果项目信息不存在，尝试解析它
        var projectInfo = await projectManager.projectInfo
        if projectInfo == nil {
            logger.debug("Project info not available, attempting to resolve...")
            do {
                projectInfo = try await projectManager.resolveProjectInfo()
            } catch {
                logger.error("Failed to resolve project info: \(error)")
                throw BuildServerError
                    .invalidConfiguration("Failed to resolve project info: \(error.localizedDescription)")
            }
        }

        guard let projectInfo else {
            throw BuildServerError.invalidConfiguration("Project info is nil after resolution attempt")
        }

        return []
        // 转换项目 targets 到 BSP BuildTarget
        // return await projectInfo.targets.compactMap { target in
        //     do {
        //         let targetId: BuildTargetIdentifier
        //         if projectInfo.projectType == .xcode {
        //             fatalError("fix me")
        // 为 Xcode 项目使用与 buildSettingsForIndex 一致的格式: xcode://path/to/project.xcodeproj/TargetName
//                    if let xcodeTargetAdapter = target as? XcodeTargetAdapter {
//                        let projectPath = xcodeTargetAdapter.projectURL.path
//                        let targetName = target.name
//                        let uri = "xcode://\(projectPath)/\(targetName)"
//                        targetId = try BuildTargetIdentifier(uri: URI(string: uri))
//                    } else {
//                        // fallback
//                        targetId = try BuildTargetIdentifier(uri: URI(string: "xcode://\(target.name)"))
//                    }
        //         targetId = try BuildTargetIdentifier(uri: URI(string: "xcode://\(target.name)"))

        //     } else {
        //         // 为 SwiftPM 项目使用简单格式
        //         targetId = try BuildTargetIdentifier(uri: URI(string: "swiftpm:///\(target.name)"))
        //     }
        //     let baseDirectory = try URI(string: projectInfo.rootURL.absoluteString)

        //     return BuildTarget(
        //         id: targetId,
        //         displayName: target.name,
        //         baseDirectory: baseDirectory,
        //         tags: [BuildTargetTag(rawValue: target.protocolProductType.rawValue)],
        //         languageIds: [Language.swift, Language.objective_c],
        //         dependencies: [],
        //         capabilities: BuildTargetCapabilities(
        //             canCompile: true,
        //             canTest: target.protocolProductType == .unitTestBundle || target
        //                 .protocolProductType == .uiTestBundle,
        //             canRun: target.protocolProductType == .application,
        //             canDebug: target.protocolProductType == .application
        //         ),
        //         dataKind: BuildTargetDataKind(rawValue: projectInfo.projectType.rawValue),
        //         data: nil
        //     )
        // } catch {
        //     logger.error("Failed to create BuildTarget for '\(target.name)': \(error)")
        //     return nil
        // }
    }

    // }

    /// 为索引构建目标（BSP 协议适配）
    func buildTargetForIndex(targets: [BuildTargetIdentifier]) async throws {
        guard let projectManager else {
            throw BuildServerError.invalidConfiguration("Project not initialized")
        }

        // 触发后台构建以支持索引
        for target in targets {
            let targetName = target.uri.stringValue.replacingOccurrences(of: "xcode://", with: "")
            await projectManager.startBuild(target: targetName)
        }
    }
}
