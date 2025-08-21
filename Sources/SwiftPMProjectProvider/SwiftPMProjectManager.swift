////
////  SwiftPMProjectManager.swift
////  SwiftPMProjectProvider Module
////
////  Copyright © 2024 Wang Lun.
////
//
// import Core
// import Foundation
//
///// SwiftPM 项目管理器
// public actor SwiftPMProjectManager: ProjectManager, ProjectStatusPublisher {
//    public let rootURL: URL
//    private let config: ProjectConfiguration?
//    public private(set) var projectInfo: (any ProjectInfo)?
//
//    public let projectType: String = "SwiftPM"
//
//    public func buildGraph() async {
//
//    }
//
//    public func buildIndex(for targets: [String]) async {
//
//    }
//
//    public func getSourceFileList(targetIdentifier: String) async -> [URL] {
//        []
//    }
//
//    public func getTargetList(includeSourceFiles: Bool) async -> [String] {
//        []
//    }
//
//    public func startBuild(targets: [String]) async {
//    }
//
//    // MARK: - State Management
//
//    private var projectState = ProjectState()
//    private var stateObservers: [WeakProjectStateObserver] = []
//
//    // MARK: - Status Observer Support (保持向后兼容)
//
//    private var observers: [WeakProjectStatusObserver] = []
//
//    public func addObserver(_ observer: ProjectStatusObserver) async {
//        observers.append(WeakProjectStatusObserver(observer))
//    }
//
//    public func removeObserver(_ observer: ProjectStatusObserver) async {
//        observers.removeAll { $0.observer === observer || $0.observer == nil }
//    }
//
//    func notifyObservers(_ event: ProjectStatusEvent) async {
//        observers.removeAll { $0.observer == nil }
//
//        for weakObserver in observers {
//            if let observer = weakObserver.observer {
//                await observer.onProjectStatusChanged(event)
//            }
//        }
//    }
//
//    // MARK: - Initialization
//
//    public init(rootURL: URL, config: ProjectConfiguration? = nil) {
//        self.rootURL = rootURL
//        self.config = config
//    }
//
//    // MARK: - ProjectManager Implementation
//
//    public func initialize() async throws {
//        // 验证 Package.swift 存在
//        let packageSwiftPath = rootURL.appendingPathComponent("Package.swift")
//        guard FileManager.default.fileExists(atPath: packageSwiftPath.path) else {
//            throw SwiftPMProjectError.invalidProject("Package.swift not found at \(rootURL.path)")
//        }
//    }
//
//    public func resolveProjectInfo() async throws -> any ProjectInfo {
//        let projectInfo = try await SwiftPMProjectInfo(
//            rootURL: rootURL,
//            name: rootURL.lastPathComponent,
//            targets: loadTargets(),
//            projectBuildSettings: SwiftPMProjectBuildSettings(rootURL: rootURL)
//        )
//
//        self.projectInfo = projectInfo
//
//        // 更新项目状态
//        let oldState = projectState.projectLoadState
//        projectState.projectLoadState = .loaded(projectInfo: projectInfo)
//        await notifyStateObservers(.projectLoadStateChanged(from: oldState, to: .loaded(projectInfo: projectInfo)))
//
//        // 向后兼容的通知
//        await notifyObservers(.projectLoaded(projectPath: rootURL.path))
//
//        return projectInfo
//    }
//
//    public func getProjectState() async -> ProjectState {
//        projectState
//    }
//
//    public func startBuild(target: String) async {
//        // 通知构建开始
//        await notifyStateObservers(.buildStarted(target: target))
//        await notifyObservers(.buildStarted(target: target))
//
//        // TODO: 实现实际的 SwiftPM 构建逻辑
//        // 这里可以调用 swift build 命令
//
//        // 模拟构建完成
//        await notifyStateObservers(.buildCompleted(target: target, success: true, duration: 1.0))
//        await notifyObservers(.buildCompleted(target: target, success: true))
//    }
//
//    // MARK: - State Observer Management
//
//    public func addStateObserver(_ observer: ProjectStateObserver) async {
//        stateObservers.append(WeakProjectStateObserver(observer))
//    }
//
//    public func removeStateObserver(_ observer: ProjectStateObserver) async {
//        stateObservers.removeAll { $0.observer === observer || $0.observer == nil }
//    }
//
//    private func notifyStateObservers(_ event: ProjectStateEvent) async {
//        stateObservers.removeAll { $0.observer == nil }
//
//        for weakObserver in stateObservers {
//            if let observer = weakObserver.observer {
//                await observer.onProjectStateChanged(event)
//            }
//        }
//    }
//
//    // MARK: - Compile Arguments
//
//    public func getCompileArguments(targetIdentifier: String, sourceFileURL sourceFileURL: String) async throws ->
//    [String] {
//        // SwiftPM 项目的基础编译参数
//        // TODO: 实现实际的 SwiftPM 编译参数获取逻辑
//        var arguments: [String] = []
//
//        // 基础 Swift 编译参数
//        arguments.append("-module-name")
//        arguments.append(rootURL.lastPathComponent)
//
//        // Debug 模式
//        arguments.append("-Onone")
//        arguments.append("-DDEBUG")
//
//        // 源文件路径
//        if let fileURL = URL(string: sourceFileURL) {
//            arguments.append(fileURL.path)
//        }
//
//        return arguments
//    }
//
//    // MARK: - Private Methods
//
//    private func loadTargets() async throws -> [any ProjectTarget] {
//        // FIXME: update targetInfo
//        [
//            SwiftPMTarget(
//                name: rootURL.lastPathComponent,
//                isSourcesResolved: false,
//                isDependenciesResolved: false,
//                sourceFiles: [],
//                dependencies: [],
//                isTestTarget: false,
//                isRunnableTarget: true
//            )
//        ]
//    }
// }
