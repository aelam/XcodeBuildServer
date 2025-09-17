# XcodeProjectManagement

A Swift library for managing Xcode projects, parsing settings, and building xcodebuild command arguments for BSP (Build Server Protocol) integration.

## Overview

This module provides comprehensive support for:

- **Project Discovery**: Automatically locate and resolve Xcode projects and workspaces
- **Settings Management**: Parse and manage Xcode build settings and configurations  
- **Command Building**: Generate properly formatted xcodebuild command arguments
- **BSP Integration**: Specialized support for Build Server Protocol workflows

## Key Components

### XcodeProjectManager

The main entry point for project management operations.

```swift
import XcodeProjectManagement

let manager = XcodeProjectManager(rootURL: projectURL)
let project = try await manager.loadProject()

// Get available schemes and configurations
let schemes = try await manager.getAvailableSchemes()
let configurations = try await manager.getAvailableConfigurations()
```

### XcodeBuildCommandBuilder  

Generates xcodebuild command arguments with type-safe options.

```swift
let commandBuilder = XcodeBuildCommandBuilder(projectInfo: project)

// Build command for iOS Simulator
let buildCommand = commandBuilder.buildCommand(
    action: .build,
    destination: .iOSSimulator
)

// Get build settings as JSON
let settingsCommand = commandBuilder.buildSettingsCommand(forIndex: true)
```

### XcodeSettingsManager

Loads and manages Xcode build settings with async support.

```swift
let settingsManager = XcodeSettingsManager(commandBuilder: commandBuilder)

// Load build settings
try await settingsManager.loadBuildSettings()
try await settingsManager.loadIndexingPaths(target: "MyTarget")

```

### XcodeProjectLocator

Low-level project discovery with BSP configuration support.

```swift
let locator = XcodeProjectLocator(root: projectURL)
let projectLocation = try locator.resolveProjectType()

switch projectLocation {
case .explicitWorkspace(let url):
    print("Found workspace: \(url)")
case .implicitProjectWorkspace(let url):
    print("Found project: \(url)")
}
```

## Project Types

- **Explicit Workspace**: A `.xcworkspace` file found in the project directory
- **Implicit Project Workspace**: A `.xcodeproj` file that contains an embedded workspace

## Build Destinations

Supported build destinations for different Apple platforms:

- `.macOS` - macOS platform
- `.iOS` - iOS device
- `.iOSSimulator` - iOS Simulator  
- `.watchOS` - watchOS device
- `.watchOSSimulator` - watchOS Simulator
- `.tvOS` - tvOS device
- `.tvOSSimulator` - tvOS Simulator
- `.custom(String)` - Custom destination string

## Build Actions

Supported xcodebuild actions:

- `.build` - Build the target
- `.clean` - Clean build products
- `.test` - Run tests
- `.archive` - Create an archive
- `.analyze` - Run static analysis
- `.install` - Install build products
- `.installsrc` - Install source code

## BSP Configuration

The module supports BSP (Build Server Protocol) configuration files:

- `.bsp/xcode.json` - Standard BSP configuration
- `buildServer.json` - Legacy configuration support 

Example configuration:
```json
{
  "workspace": "MyProject.xcworkspace",
  "scheme": "MyScheme",
  "configuration": "Debug"
}
```

## Thread Safety

All public APIs are designed to be thread-safe:

- `XcodeProjectManager` is an `actor` for safe concurrent access
- `XcodeSettingsManager` is an `actor` for safe concurrent access  
- All data structures conform to `Sendable` where applicable

## Error Handling

The module provides comprehensive error handling through `XcodeProjectError`:

- `.notFound` - No Xcode project found
- `.multipleWorkspaces([URL])` - Multiple workspaces found, specify one in config
- `.invalidConfig(String)` - Invalid or malformed configuration

## Integration

This module integrates seamlessly with the main sourcekit-bsp for BSP support, but can also be used independently for general Xcode project management tasks.
