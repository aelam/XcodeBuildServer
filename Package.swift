// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XcodeBuildServer",
    platforms: [.macOS(.v13)],
    products: [
        // 核心库
        .library(name: "Core", targets: ["Core"]),
        .library(name: "JSONRPCConnection", targets: ["JSONRPCConnection"]),
        .library(name: "Logger", targets: ["Logger"]),
        .library(name: "BSPServer", targets: ["BSPServer"]),

        // 项目提供者库
        .library(name: "SwiftPMProjectProvider", targets: ["SwiftPMProjectProvider"]),
        .library(name: "XcodeProjectProvider", targets: ["XcodeProjectProvider"]),

        // CLI工具
        .executable(name: "XcodeBuildServerCLI", targets: ["XcodeBuildServerCLI"]),
        .executable(name: "XcodeProjectCLI", targets: ["XcodeProjectCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "2.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.12.0")),
    ],
    targets: [
        // 跨平台核心模块
        .target(
            name: "Core",
            dependencies: []
        ),
        .target(
            name: "JSONRPCConnection",
            dependencies: ["Logger"]
        ),
        .target(
            name: "Logger",
            dependencies: [
                .product(
                    name: "SwiftyBeaver",
                    package: "SwiftyBeaver"
                ),
            ]
        ),

        // BSP 服务器模块
        .target(
            name: "BSPServer",
            dependencies: [
                "Core",
                "JSONRPCConnection",
                "Logger",
                "SwiftPMProjectProvider",
                // XcodeProjectProvider 只在 macOS 下有效
                "XcodeProjectProvider"
            ]
        ),

        // SwiftPM 项目提供者 (跨平台)
        .target(
            name: "SwiftPMProjectProvider",
            dependencies: ["Core", "Logger"]
        ),

        // Xcode 项目管理 (macOS专用)
        .target(
            name: "XcodeProjectManagement",
            dependencies: [
                "Core",
                "Logger",
                .product(
                    name: "XcodeProj",
                    package: "XcodeProj",
                    condition: .when(platforms: [.macOS])
                ),
            ],
            swiftSettings: [
                .define("MACOS_ONLY", .when(platforms: [.macOS]))
            ]
        ),

        // Xcode 项目提供者 (macOS专用)
        .target(
            name: "XcodeProjectProvider",
            dependencies: [
                "XcodeProjectManagement"
            ],
            swiftSettings: [
                .define("MACOS_ONLY", .when(platforms: [.macOS]))
            ]
        ),

        // CLI 工具
        .executableTarget(
            name: "XcodeBuildServerCLI",
            dependencies: [
                "BSPServer",
                "Logger",
            ]
        ),
        .executableTarget(
            name: "XcodeProjectCLI",
            dependencies: [
                "XcodeProjectProvider",
                "Logger",
            ],
            swiftSettings: [
                .define("MACOS_ONLY", .when(platforms: [.macOS]))
            ]
        ),

        // 测试
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
        .testTarget(
            name: "BSPServerTests",
            dependencies: ["BSPServer"],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "SwiftPMProjectProviderTests",
            dependencies: ["SwiftPMProjectProvider"]
        ),
        .testTarget(
            name: "XcodeProjectProviderTests",
            dependencies: ["XcodeProjectProvider"],
            resources: [
                .copy("README.md"),
                .copy("Resources")
            ]
        ),
    ]
)
