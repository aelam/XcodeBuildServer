// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XcodeBuildServer",
    platforms: [.macOS(.v13)],
    products: [
        // Base
        .library(name: "Core", targets: ["Core"]),
        .library(name: "JSONRPCConnection", targets: ["JSONRPCConnection"]),
        .library(name: "Logger", targets: ["Logger"]),
        .library(name: "BSPServer", targets: ["BSPServer"]),

        // ProjectManagerProviders
        .library(name: "SwiftPMProjectManagerProvider", targets: ["SwiftPMProjectManagerProvider"]),
        .library(name: "XcodeProjectManagerProvider", targets: ["XcodeProjectManagerProvider"]),

        // CLI Tools
        .executable(name: "XcodeBuildServerCLI", targets: ["XcodeBuildServerCLI"]),
        .executable(name: "XcodeProjectCLI", targets: ["XcodeProjectCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "2.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.12.0")),
    ],
    targets: [
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
                "SwiftPMProjectManagerProvider",
                "XcodeProjectManagerProvider"
            ]
        ),

        // SwiftPM 项目提供者 (跨平台)
        .target(
            name: "SwiftPMProjectManagerProvider",
            dependencies: ["Core", "Logger"]
        ),

        // Xcode mac only
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
            resources: [
                .copy("README.md"),
            ],
            swiftSettings: [
                .define("MACOS_ONLY", .when(platforms: [.macOS]))
            ]
        ),

        // XcodeProjectManagerProvider (MacOS only)
        .target(
            name: "XcodeProjectManagerProvider",
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
                "XcodeProjectManagerProvider",
                "Logger",
            ],
            swiftSettings: [
                .define("MACOS_ONLY", .when(platforms: [.macOS]))
            ]
        ),

        // MARK: - Tests

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
            name: "SwiftPMProjectManagerProviderTests",
            dependencies: ["SwiftPMProjectManagerProvider"]
        ),
        .testTarget(
            name: "XcodeProjectManagerProviderTests",
            dependencies: ["XcodeProjectManagerProvider"]
        ),
        .testTarget(
            name: "XcodeProjectManagementTests",
            dependencies: [],
            resources: [
                .copy("README.md"),
                .copy("Resources")
            ]
        ),
    ]
)
