# BSP TaskProgress 异步更新解决方案

## 问题分析

你提出的问题很重要：**`startBuild → updateProgress → finish` 会顺序执行，没办法异步更新task状态**

这是因为 `ProjectManager.startBuild()` 是同步等待完成的，在构建过程中无法获得中间进度。

## 解决方案

我实现了 3 种不同的方案来解决这个问题：

### 方案1: 异步进度模拟 (`executeBuild`)

**位置**: `BSPTaskManager+Build.swift`

**原理**: 在调用 `startBuild` 的同时，启动一个异步任务来模拟进度更新

```swift
// 启动异步进度更新任务
let progressTask = Task {
    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒后开始
    try? await task.updateProgress(progress: 0.3, message: "Compiling...")
    
    // 继续模拟进度更新...
}

// 执行实际构建（这会阻塞直到完成）
let status = try await projectManager.startBuild(targetIdentifiers: targets)

// 取消进度更新任务
progressTask.cancel()
```

**优点**: 
- ✅ 简单易实现
- ✅ 不需要修改现有 ProjectManager 接口
- ✅ 客户端能看到进度更新

**缺点**: 
- ❌ 进度是模拟的，不反映真实构建状态
- ❌ 无法知道实际构建进度

### 方案2: 分目标构建 (`executeBuildWithRealTimeProgress`)

**位置**: `BSPTaskManager+RealTimeBuild.swift`

**原理**: 逐个构建目标，在每个目标构建过程中异步更新进度

```swift
for (index, target) in targets.enumerated() {
    // 启动异步进度模拟器
    let progressSimulator = Task {
        // 持续更新该目标的构建进度
    }
    
    // 执行单个目标的构建
    let result = try await projectManager.startBuild(targetIdentifiers: [target])
    
    // 停止进度模拟器
    progressSimulator.cancel()
}
```

**优点**: 
- ✅ 能够区分不同目标的构建进度
- ✅ 比方案1更精确
- ✅ 支持多目标构建的进度跟踪

**缺点**: 
- ❌ 仍然是模拟进度，不是真实进度
- ❌ 分别构建目标可能不如批量构建高效

### 方案3: 解析构建输出 (`executeBuildWithParsedProgress`)

**位置**: `BSPTaskManager+ParsedBuild.swift`

**原理**: 直接调用构建工具，解析其输出来获得真实进度

```swift
// 解析 xcodebuild 输出来提取进度信息
private func parseXcodeBuildProgress(_ output: String) -> (progress: Double, message: String)? {
    if output.contains("Building target") {
        return (0.3, "Building target...")
    } else if output.contains("Compiling") {
        // 解析 "Compiling MyFile.swift (5 of 20)" 格式
        return (0.6, "Compiling files...")
    } else if output.contains("Linking") {
        return (0.9, "Linking...")
    }
    return nil
}
```

**优点**: 
- ✅ 真实的构建进度
- ✅ 能够提供详细的构建状态信息
- ✅ 最准确的进度报告

**缺点**: 
- ❌ 实现复杂，需要解析不同构建工具的输出格式
- ❌ 需要修改更多代码
- ❌ 依赖于构建工具的输出格式

## 当前选择

我已经将 **方案2 (`executeBuildWithRealTimeProgress`)** 设置为默认使用的方案，因为它在实现复杂度和用户体验之间取得了最好的平衡。

## 使用方式

```swift
// 在 BSPServerService.compileTargets() 中
return try await taskManager.executeBuildWithRealTimeProgress(
    using: projectManager,
    targets: targetIdentifiers,
    originId: originId
)
```

## 客户端体验

现在客户端会看到：

1. **taskStart**: "Building targets: MyApp, MyTests"
2. **taskProgress** (0.1): "Starting build for target: MyApp"
3. **taskProgress** (0.3): "Building MyApp... (30%)"
4. **taskProgress** (0.5): "Building MyApp... (50%)"
5. **taskProgress** (0.7): "Building MyApp... (70%)"
6. **taskProgress** (0.55): "Starting build for target: MyTests"
7. **taskProgress** (0.8): "Building MyTests... (80%)"
8. **taskProgress** (1.0): "Build completed successfully"
9. **taskFinish**: Success

## 未来改进

未来可以考虑：
1. 实现方案3的真实进度解析
2. 结合方案1和方案2的优点
3. 添加构建取消功能
4. 更精确的时间估算

你的观察很准确，这确实是一个需要解决的重要问题！
