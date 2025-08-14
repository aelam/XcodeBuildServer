# WorkspaceBuildTargetsRequest 和 textDocument/sourceKitOptions 实现完成

## 实现总结

我已经成功实现了核心的 BSP 方法，包括 `WorkspaceBuildTargetsRequest` 和 `textDocument/sourceKitOptions`：

### 1. 增强的 XcodeProjectManager
- 添加了 `getAvailableTargets()` 方法来发现项目中的所有目标
- 添加了 `getTargetBuildSettings(target:)` 方法来获取特定目标的构建设置
- 添加了 `extractTargetInfo()` 方法来提取完整的目标信息
- 实现了解析逻辑来处理 `xcodebuild -list` 和 `-showBuildSettings` 的输出

### 2. XcodeTargetInfo 结构
- 新增了 `XcodeTargetInfo` 结构来封装目标的详细信息
- 包含智能分类逻辑来识别：
  - 应用程序目标 (`isApplicationTarget`)
  - 测试目标 (`isTestTarget`)
  - UI 测试目标 (`isUITestTarget`)
  - 库目标 (`isLibraryTarget`)
  - 可运行目标 (`isRunnableTarget`)
- 自动检测支持的编程语言（Swift, Objective-C, C, C++）

### 3. BuildServerContext 工厂方法
- 实现了 `createBuildTargets()` 方法作为主要入口点
- 创建了 `createBuildTarget()` 来将 XcodeTargetInfo 映射到 BSP BuildTarget
- 实现了目标分类逻辑（application, library, test, integration-test）
- 添加了 SourceKit 数据支持，包括 toolchain 信息

### 4. WorkspaceBuildTargetsRequest 处理器
- 完全实现了 BSP 规范的 `workspace/buildTargets` 端点
- 支持目标过滤（如果在请求中指定了特定目标）
- 使用新的 ContextualRequestType 模式进行类型安全的上下文访问
- 包含完整的错误处理

### 5. WorkspaceBuildTargetsResponse
- 创建了符合 BSP 规范的响应结构
- 返回完整的 BuildTarget 数组，包含所有必需的元数据

### 6. textDocument/sourceKitOptions 完整实现 ✨
- **数据源**：使用 `buildSettingsForIndex` 而非普通构建设置
- **目标特异性**：支持不同构建目标的不同编译参数
- **文件特异性**：为特定文件返回专门的编译设置
- **BuildServerContext 方法**：
  - `getCompileArguments(target:fileURI:)` - 获取文件编译参数
  - `extractSchemeFromBuildTarget(_:)` - 解析目标scheme名称
  - `getWorkingDirectory()` - 获取工作目录
- **错误处理**：完善的后备机制和错误恢复策略
- **日志记录**：详细的调试和故障排除信息

## textDocument/sourceKitOptions 数据流

```
BSP Client Request (textDocument/sourceKitOptions)
    ↓
TextDocumentSourceKitOptionsRequest
    ↓  
BuildServerContext.getCompileArguments()
    ↓
extractSchemeFromBuildTarget() → parse "xcode:///ProjectPath/SchemeName/TargetName"
    ↓
XcodeProjectInfo.buildSettingsForIndex[scheme][filePath]
    ↓
XcodeFileBuildSettingInfo.swiftASTCommandArguments
    ↓
TextDocumentSourceKitOptionsResponse with compiler arguments
```

## BSP BuildTarget 映射

每个 Xcode 目标现在映射为一个 BuildTarget，包含：

- **ID**: `xcode:///ProjectPath/TargetName` 格式的 URI
- **DisplayName**: 目标的可读名称
- **BaseDirectory**: 项目根目录
- **Tags**: 基于目标类型的分类标签
- **LanguageIds**: 检测到的编程语言
- **Capabilities**: 支持的操作（编译、测试、运行、调试）
- **DataKind**: 设置为 "sourceKit"
- **Data**: 包含 toolchain 路径的 SourceKitBuildTarget

## 数据流

```
BSP Client Request
    ↓
WorkspaceBuildTargetsRequest
    ↓
BuildServerContext.createBuildTargets()
    ↓
XcodeProjectManager.extractTargetInfo()
    ↓
xcodebuild -list & -showBuildSettings
    ↓
XcodeTargetInfo objects
    ↓
BuildTarget objects
    ↓
WorkspaceBuildTargetsResponse
```

## 使用示例

### workspace/buildTargets 请求

当 BSP 客户端发送请求时：

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "workspace/buildTargets",
  "params": {
    "targets": []
  }
}
```

服务器将返回：

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "targets": [
      {
        "id": { "uri": "xcode:///MyApp/MyApp" },
        "displayName": "MyApp",
        "tags": ["application"],
        "languageIds": ["swift"],
        "capabilities": {
          "canCompile": true,
          "canRun": true,
          "canTest": false,
          "canDebug": true
        },
        "dataKind": "sourceKit",
        "data": {
          "toolchain": "file:///Applications/Xcode.app"
        }
      }
    ]
  }
}
```

### textDocument/sourceKitOptions 请求

当 BSP 客户端请求特定文件的编译选项时：

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "textDocument/sourceKitOptions",
  "params": {
    "textDocument": { "uri": "file:///path/to/MyApp/ViewController.swift" },
    "target": { "uri": "xcode:///MyApp/MyScheme/MyApp" },
    "language": "swift"
  }
}
```

服务器将返回实际的编译器参数：

```json
{
  "jsonrpc": "2.0", 
  "id": 2,
  "result": {
    "compilerArguments": [
      "-module-name", "MyApp",
      "-Onone",
      "-enforce-exclusivity=checked", 
      "/path/to/MyApp/ViewController.swift",
      "-DDEBUG",
      "-sdk", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.1.sdk",
      "-target", "arm64-apple-ios18.0",
      "-g",
      "-index-store-path", "/Users/user/Library/Developer/Xcode/DerivedData/MyApp-hash/Index.noindex/DataStore",
      "-swift-version", "5"
    ],
    "workingDirectory": "/path/to/MyApp"
  }
}
```

现在 `WorkspaceBuildTargetsRequest` 和 `textDocument/sourceKitOptions` 都已经完全实现，为 SourceKit-LSP 提供了完整的语义支持。