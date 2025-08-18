# BSP服务器实现指南 - XcodeBuildServer

基于 [SourceKit-LSP官方BSP服务器实现指南](https://github.com/swiftlang/sourcekit-lsp/blob/56a91e90212400f20bb9d3f2e563ea8cda7634f6/Contributor%20Documentation/Implementing%20a%20BSP%20server.md) 的完整实现文档。

## 概述

SourceKit-LSP可以通过[Build Server Protocol (BSP)](https://build-server-protocol.github.io/)连接到任何构建系统以提供语义功能。本文档详细说明了为SourceKit-LSP实现BSP服务器所需要实现的请求和通知。

## 必需的生命周期方法

为了能够成功启动和关闭，BSP服务器必须实现以下方法：

### 1. `build/initialize`
- **用途**：初始化BSP服务器
- **必需响应字段**：
  ```json
  {
    "displayName": "XcodeBuildServer",
    "version": "1.0.0",
    "bspVersion": "2.2.0",
    "capabilities": {
      "languageIds": ["swift", "objective-c", "objective-cpp", "c", "cpp"]
    },
    "dataKind": "sourceKit",
    "data": {
      "sourceKitOptionsProvider": true,
      "indexDatabasePath": "/path/to/index/database",
      "indexStorePath": "/path/to/index/store",
      "prepareProvider": true
    }
  }
  ```

### 2. `build/initialized`
- **用途**：通知服务器初始化完成
- **实现**：开始观察文件系统变化

### 3. `build/shutdown`
- **用途**：请求关闭服务器
- **实现**：清理资源，停止后台任务

### 4. `build/exit`
- **用途**：立即退出服务器进程
- **实现**：强制终止进程

## 构建设置检索方法

为了为源文件提供语义功能，BSP服务器必须提供以下方法：

### 1. `workspace/buildTargets`
- **用途**：返回工作区中所有可用的构建目标
- **响应格式**：
  ```json
  {
    "targets": [
      {
        "id": { "uri": "xcode:///ProjectPath/SchemeName/TargetName" },
        "displayName": "SchemeName/TargetName",
        "baseDirectory": "file:///path/to/project",
        "tags": ["application", "library", "test"],
        "languageIds": ["swift", "objective-c"],
        "capabilities": {
          "canCompile": true,
          "canTest": true,
          "canRun": true,
          "canDebug": true
        },
        "dataKind": "sourceKit",
        "data": {
          "toolchain": "file:///Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
        }
      }
    ]
  }
  ```

### 2. `buildTarget/sources`
- **用途**：返回指定构建目标的源文件列表
- **实现状态**：✅ 已实现

### 3. `textDocument/sourceKitOptions`
- **用途**：为特定文件返回编译选项
- **实现状态**：✅ 已完成实现
- **数据源**：`buildSettingsForIndex`
- **请求参数**：
  - `textDocument.uri`: 文件路径
  - `target`: 构建目标标识符（格式：`xcode:///ProjectPath/SchemeName/TargetName`）
  - `language`: 编程语言
- **响应字段**：
  - `compilerArguments`: 编译器参数数组
  - `workingDirectory`: 工作目录路径
- **关键实现**：
  ```swift
  // 1. 从BuildTargetIdentifier提取scheme名称
  private func extractSchemeFromBuildTarget(_ target: BuildTargetIdentifier) -> String? {
      let uriString = target.uri.stringValue
      guard uriString.hasPrefix("xcode:///") else { return nil }
      let pathComponents = uriString.dropFirst("xcode:///".count).split(separator: "/")
      return pathComponents.count >= 2 ? String(pathComponents[1]) : nil
  }
  
  // 2. 获取编译参数
  func getCompileArguments(target: BuildTargetIdentifier, fileURI: String) async throws -> [String] {
      let targetScheme = extractSchemeFromBuildTarget(target)
      let filePath = URL(string: fileURI)?.path ?? fileURI
      return buildSettingsForIndex[targetScheme]?[filePath]?.swiftASTCommandArguments ?? []
  }
  ```
- **错误处理**：
  - 无 `buildSettingsForIndex` 时返回空数组
  - 无法解析目标scheme时记录警告
  - 找不到文件特定设置时使用首个可用文件设置作为后备
  - 异常时返回 `nil` 结果

### 4. `buildTarget/didChange`
- **用途**：通知构建目标发生变化
- **实现**：当项目配置改变时发送通知

### 5. `workspace/waitForBuildSystemUpdates`
- **用途**：等待构建系统更新完成
- **实现**：对于Xcode项目，通常立即返回

## 背景索引支持

要支持背景索引，构建服务器必须：

1. 在`build/initialize`响应中设置`data.prepareProvider: true`
2. 实现`buildTarget/prepare`方法
3. 确保准备目标时使用的编译器选项与`textDocument/sourceKitOptions`发送的选项匹配

### `buildTarget/prepare`
- **用途**：准备构建目标用于索引
- **实现状态**：🔄 基础实现完成

## textDocument/sourceKitOptions 详细实现

`textDocument/sourceKitOptions` 是BSP协议中最重要的方法之一，为SourceKit-LSP提供特定文件的编译器选项。

### 实现架构

```
客户端请求 → TextDocumentSourceKitOptionsRequest → BuildServerContext → XcodeProjectInfo → buildSettingsForIndex
```

### 数据流程

1. **请求解析**：
   ```swift
   public struct Params: Codable, Sendable {
       public var textDocument: TextDocumentIdentifier  // 文件URI
       public var target: BuildTargetIdentifier         // 目标标识符
       public var language: Language                    // 编程语言
   }
   ```

2. **目标解析**：


3. **编译参数获取**：
   ```swift
   func getCompileArguments(target: BuildTargetIdentifier, fileURI: String) async throws -> [String] {
       let state = try loadedState
       guard let buildSettingsForIndex = state.xcodeProjectInfo.buildSettingsForIndex else {
           logger.warning("No buildSettingsForIndex available")
           return []
       }
       
       let targetScheme = extractSchemeFromBuildTarget(target)
       let filePath = URL(string: fileURI)?.path ?? fileURI
       
       guard let targetSettings = buildSettingsForIndex[targetScheme],
             let fileBuildSettings = targetSettings[filePath] else {
           // 后备策略：使用第一个可用文件的设置
           if let firstFileSettings = buildSettingsForIndex[targetScheme]?.values.first {
               return firstFileSettings.swiftASTCommandArguments ?? []
           }
           return []
       }
       
       return fileBuildSettings.swiftASTCommandArguments ?? []
   }
   ```

### 响应格式

```swift
public struct Result: Codable, Hashable, Sendable {
    /// 编译器选项列表
    public let compilerArguments: [String]
    
    /// 编译命令的工作目录
    public let workingDirectory: String?
}
```

### 典型的编译参数示例

```json
{
  "compilerArguments": [
    "-module-name", "Hello",
    "-Onone",
    "-enforce-exclusivity=checked",
    "/Users/user/project/Hello/Hello.swift",
    "-DDEBUG",
    "-enable-bare-slash-regex",
    "-sdk", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.1.sdk",
    "-target", "arm64-apple-ios18.0",
    "-g",
    "-module-cache-path", "/Users/user/Library/Developer/Xcode/DerivedData/ModuleCache.noindex",
    "-index-store-path", "/Users/user/Library/Developer/Xcode/DerivedData/Hello-hash/Index.noindex/DataStore",
    "-swift-version", "5",
    "-working-directory", "/Users/user/project/Hello"
  ],
  "workingDirectory": "/Users/user/project/Hello"
}
```

### 错误处理策略

1. **无 buildSettingsForIndex**：
   - 记录警告日志
   - 返回空编译参数数组

2. **无法解析目标Scheme**：
   - 记录警告并显示原始URI
   - 返回空数组

3. **文件特定设置缺失**：
   - 尝试使用同scheme下第一个可用文件的设置
   - 记录调试信息说明使用了后备策略

4. **异常情况**：
   - 捕获并记录错误详情
   - 返回 `nil` 结果让客户端知道获取失败

### 关键特性

- ✅ **目标特异性**：不同构建目标返回不同编译参数
- ✅ **文件特异性**：为特定文件返回专门的编译设置
- ✅ **数据源正确性**：使用 `buildSettingsForIndex` 而非普通 buildSettings
- ✅ **后备机制**：当特定文件设置不可用时的智能降级
- ✅ **详细日志**：提供完整的调试信息追踪

## 可选方法

以下方法不是SourceKit-LSP工作所必需的，但可能有助于BSP服务器的实现：

### 1. `build/logMessage`
- **用途**：向客户端发送日志消息
- **实现状态**：❌ 未实现

### 2. 任务进度通知
- `build/taskStart`: 任务开始
- `build/taskProgress`: 任务进度更新  
- `build/taskFinish`: 任务完成
- **实现状态**：❌ 未实现

### 3. `workspace/didChangeWatchedFiles`
- **用途**：文件系统变化通知
- **实现状态**：✅ 已实现

### 4. `window/showMessage`
- **用途**：处理SourceKit-LSP发送的用户消息
- **实现状态**：✅ 已实现

## XcodeBuildServer特有实现

### 项目发现和解析
```swift
// 1. 项目发现
let projectManager = XcodeProjectManager(rootURL: rootURL)
try await projectManager.resolveProjectInfo()

// 2. Scheme解析
let schemes = try await projectManager.extractSchemes()

// 3. 构建目标映射
let buildTargets = try await createBuildTargets(from: schemes)
```

### 编译参数提取
```swift
// 使用xcodebuild获取构建设置
let buildSettings = try await xcodebuild.getBuildSettings(
    for: target,
    scheme: scheme,
    configuration: configuration
)
```

### 工具链配置
```swift
// 工具链路径配置
let toolchainPath = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
let toolchainURI = URI(string: "file://\(toolchainPath)")
```

## 构建服务器发现

创建`buildServer.json`文件在项目根目录：

```json
{
  "name": "XcodeBuildServer",
  "version": "1.0.0",
  "bspVersion": "2.2.0",
  "languages": ["swift", "objective-c", "objective-cpp", "c", "cpp"],
  "argv": ["/path/to/XcodeBuildServerCLI"],
  "rootUri": "file:///path/to/project"
}
```

## 实现状态检查清单

### 必需方法
- [x] `build/initialize`
- [x] `build/initialized` 
- [x] `build/shutdown`
- [x] `build/exit`
- [x] `workspace/buildTargets`
- [x] `buildTarget/sources`
- [x] `textDocument/sourceKitOptions` - ✅ **完整实现，使用buildSettingsForIndex数据源**
- [x] `buildTarget/didChange`
- [x] `workspace/waitForBuildSystemUpdates`

### 背景索引
- [x] `buildTarget/prepare` (基础实现)

### 可选方法
- [x] `workspace/didChangeWatchedFiles`
- [x] `window/showMessage`
- [ ] `build/logMessage`
- [ ] `build/taskStart/Progress/Finish`

### Xcode集成
- [x] 项目解析 (.xcodeproj/.xcworkspace)
- [x] Scheme解析
- [x] 构建设置提取
- [x] 工具链配置
- [x] 语言检测

## 调试和故障排除

### 日志配置
```swift
// 启用详细日志
logger.logLevel = .debug

// 关键日志点
logger.debug("JSONRPCServer received message: \(message)")
logger.debug("Successfully sent response for request ID: \(requestID)")
logger.info("Generated toolchain URI: \(toolchainURI)")
```

### 常见问题
1. **工具链路径错误**：确保toolchain URI指向包含`usr`目录的路径
2. **编译参数不匹配**：验证`textDocument/sourceKitOptions`与实际构建参数一致
3. **索引路径配置**：确保indexStorePath和indexDatabasePath正确设置

## 参考文档

- [BSP协议规范](https://build-server-protocol.github.io/docs/specification)
- [SourceKit-LSP BSP扩展](https://github.com/swiftlang/sourcekit-lsp/blob/main/Contributor%20Documentation/BSP%20Extensions.md)
- [SourceKit-LSP实现指南](https://github.com/swiftlang/sourcekit-lsp/blob/main/Contributor%20Documentation/Implementing%20a%20BSP%20server.md)

## 版本历史

- v0.0.1: 初始实现，支持基本BSP协议
- v0.0.1: 添加window/showMessage支持
- v0.0.1: 改进buildTargets实现和工具链配置
- v0.0.1: **[待发布] 完整实现textDocument/sourceKitOptions**
  - 使用buildSettingsForIndex作为数据源
  - 支持目标和文件特异性编译参数
  - 完善的错误处理和后备机制
  - 详细的调试日志记录
