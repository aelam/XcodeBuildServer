# XcodeBuildServer

[![Swift](https://img.shields.io/badge/swift-6.1+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://developer.apple.com/macos/)
[![Build Status](https://github.com/aelam/XcodeBuildServer/workflows/CI/badge.svg)](https://github.com/aelam/XcodeBuildServer/actions)
[![codecov](https://codecov.io/github/aelam/XcodeBuildServer/graph/badge.svg?token=SUL2UI5FQD)](https://codecov.io/github/aelam/XcodeBuildServer)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Build Server Protocol (BSP) implementation for Xcode projects, enabling better IDE integration with Swift and Objective-C codebases.

## Features

- 🔧 **BSP 2.0 Support**: Full compatibility with Build Server Protocol 2.0
- 🏗️ **Xcode Integration**: Seamless integration with Xcode build system
- ⚡ **Fast Indexing**: Efficient source code indexing and navigation
- 📁 **Multi-target Support**: Support for complex Xcode project structures
- 🔍 **SourceKit Integration**: Native Swift language server capabilities
- 🛡️ **Thread-safe**: Robust concurrent operations with Swift actors

## Installation

### Homebrew (Recommended)
```bash
# Coming soon
brew install XcodeBuildServer
```

### Manual Installation
1. Download the latest release from [GitHub Releases](https://github.com/wang.lun/XcodeBuildServer/releases)
2. Extract and move to your PATH:
   ```bash
   tar -xzf xcode-build-server-macos-universal.tar.gz
   sudo mv xcode-build-server /usr/local/bin/
   chmod +x /usr/local/bin/XcodeBuildServerCLI
   ```

### Build from Source
```bash
git clone https://github.com/wang.lun/XcodeBuildServer.git
cd XcodeBuildServer
swift build -c release
cp .build/release/XcodeBuildServerCLI /usr/local/bin/XcodeBuildServerCLI
```

## Quick Start

1. **Configure your project**: 
   1. Create a `.bsp/XcodeBuildServer.json` in your project root. The deprecated way is to create a `buildServer.json` file in your project root:
   ```json
   {
      "name": "XcodeBuildServer",
      "version": "0.2",
      "bspVersion": "2.0",
      "languages": [
         "objective-c",
         "objective-cpp",
         "swift"
      ],
      "argv": [
         "path/to/XcodeBuildServerCLI"
      ],
      "kind": "xcode"
   }
   ```
   2. Create a `.bsp/xcode.json` configuration file in your project root:
   ```json
   {
     "workspace": "YourProject.xcworkspace",
     "scheme": "YourScheme",
     "configuration": "Debug"
   }
   ```

3. **Start the server**:
   ```shell
   XcodeBuildServerCLI
   ```

4. **Connect from your IDE**: Configure your IDE to connect to the BSP server (typically on stdio).

## Configuration

The build server looks for configuration in the following order:
1. `.bsp/*.json` files (BSP standard)
   1. `xcode.json` in `.bsp/` directory for your project/workspace
   2. `xcode.json` in `.bsp/` directory is not necessary if you have only one project or one workspace
2. `buildServer.json` in project root (legacy support)

### xcode.json Configuration Options
```json
{
  "workspace": "YourProject.xcworkspace",
  "project": "YourProject.xcodeproj",
  "scheme": "YourScheme",
  "configuration": "Debug"
}
```

| Option | Description | Required |
|--------|-------------|----------|
| `workspace` | Path to .xcworkspace file | Yes* |
| `project` | Path to .xcodeproj file | Yes* |
| `scheme` | Xcode scheme to use | Yes |
| `configuration` | Build configuration (Debug/Release) | No (defaults to Debug) |

*Either `workspace` or `project` is required.

## IDE Integration

### VS Code with SourceKit-LSP
```json
{
  "sourcekit-lsp.serverPath": "/path/to/sourcekit-lsp",
  "sourcekit-lsp.toolchainPath": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
}
```

### Vim/Neovim
Use with [vim-lsp](https://github.com/prabirshrestha/vim-lsp) or [coc.nvim](https://github.com/neoclide/coc.nvim).

## Development

### Prerequisites
- macOS 12.0+
- Xcode 14.0+
- Swift 6.1+

### Building
```bash
swift build
```

### Testing
```bash
swift test
```

### Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Architecture

```
┌─────────────────┐    JSON-RPC    ┌──────────────────┐
│       IDE       │ ◄─────────────► │ XcodeBuildServer │
└─────────────────┘                └──────────────────┘
                                            │
                                            ▼
                                   ┌─────────────────┐
                                   │ Xcode Build     │
                                   │ System          │
                                   └─────────────────┘
```

### Key Components

- **BSPServer**: Core BSP protocol implementation
- **BuildServerContext**: Manages project state and configuration
- **JSONRPCServer**: JSON-RPC transport layer
- **XcodeBuild Integration**: Interface with xcodebuild tool

## Troubleshooting

### Common Issues

1. **Server not starting**: Check that your configuration file is valid JSON
2. **Build failures**: Ensure your Xcode project builds successfully first
3. **Index not updating**: Verify that the scheme and configuration are correct

### Logging

Enable debug logging:
```bash
export XCODE_BUILD_SERVER_LOG_LEVEL=debug
xcode-build-server
```

## References

- [Build Server Protocol Specification](https://build-server-protocol.github.io/)
- [SourceKit-LSP](https://github.com/apple/sourcekit-lsp)
- [Swift Package Manager BSP](https://github.com/apple/swift-package-manager/blob/main/Documentation/BuildServerProtocol.md)

Inspired by [sourcekit-bazel-bsp](https://github.com/spotify/sourcekit-bazel-bsp)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Apple for SourceKit and the Swift toolchain
- The Build Server Protocol community
- Contributors to the Swift ecosystem
