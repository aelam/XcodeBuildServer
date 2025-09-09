# BSP Task Progress 使用示例

## 概述

BSPTaskManager 现在支持完整的任务进度报告，包括 `taskStart`、`taskProgress` 和 `taskFinish` 通知。

## 功能特性

### 1. 任务生命周期管理
- **taskStart**: 任务开始时发送，包含任务ID、originId、消息和目标
- **taskProgress**: 任务执行过程中发送，包含进度百分比和状态消息
- **taskFinish**: 任务结束时发送，包含最终状态和消息

### 2. 智能进度报告
- 自动进度计算（0.0 - 1.0）
- 多目标构建时分步骤报告进度
- 详细的状态消息

## 使用方法

```swift
// 在 BSPServerService 中使用
let taskManager = BSPTaskManager(notificationSender: self)

// 执行构建并自动报告进度
let status = try await taskManager.executeBuild(
    using: projectManager,
    targets: targetIdentifiers,
    originId: request.id
)
```

## 进度报告阶段

### 单目标构建
1. **10%** - "Starting build..."
2. **20%** - "Preparing build..."
3. **50%** - "Compiling..."
4. **100%** - "Build completed successfully" / "Build completed with errors"

### 多目标构建
1. **10%** - "Starting build..."
2. **20%** - "Preparing build..."
3. **30-80%** - "Building target: [TargetName]" (每个目标分配进度)
4. **100%** - "Build completed successfully" / "Build completed with errors"

## BSP 通知示例

### taskStart 通知
```json
{
    "jsonrpc": "2.0",
    "method": "build/taskStart",
    "params": {
        "taskId": "task-1-1725897600.123",
        "originId": "build-request-1",
        "message": "Building targets: MyApp",
        "targets": [
            {
                "uri": "MyApp"
            }
        ]
    }
}
```

### taskProgress 通知
```json
{
    "jsonrpc": "2.0",
    "method": "build/taskProgress",
    "params": {
        "taskId": "task-1-1725897600.123",
        "progress": 0.5,
        "message": "Compiling..."
    }
}
```

### taskFinish 通知
```json
{
    "jsonrpc": "2.0",
    "method": "build/taskFinish",
    "params": {
        "taskId": "task-1-1725897600.123",
        "status": 1,
        "message": "Build completed successfully"
    }
}
```

## 调用链

```
BSPServerService.buildTarget()
    ↓
TaskManager.executeBuild()
    ↓ (发送 taskStart)
ProjectManagerProvider.getProjectManager()
    ↓
ProjectManager.startBuild()
    ↓ (发送多个 taskProgress)
XcodeBuildExecutor.executeXcodeBuild() / SwiftBuildExecutor.executeSwiftBuild()
    ↓ (发送 taskFinish)
返回 StatusCode
```

## 错误处理

如果构建失败，TaskManager 会：
1. 调用 `task.fail(message: "Build failed: [error]")`
2. 发送 taskFinish 通知，status = .error
3. 抛出原始错误供上层处理

## 扩展计划

未来可以考虑：
1. 解析 xcodebuild 输出，提供更精确的进度
2. 支持取消构建操作
3. 添加构建时间估算
4. 更详细的编译文件进度报告
