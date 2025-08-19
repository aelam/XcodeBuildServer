// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XcodeBuildServer",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "JSONRPCConnection",
            targets: ["JSONRPCConnection"]
        ),
        .library(
            name: "Logger",
            targets: ["Logger"]
        ),
        .library(
            name: "XcodeBuildServer",
            targets: ["XcodeBuildServer"]
        ),
        .library(
            name: "XcodeProjectManagement",
            targets: ["XcodeProjectManagement"]
        ),
        .executable(
            name: "XcodeBuildServerCLI",
            targets: [
                "XcodeBuildServer",
                "XcodeBuildServerCLI",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "2.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.12.0")),
    ],
    targets: [
        .target(
            name: "JSONRPCConnection",
            dependencies: [
                "Logger"
            ]
        ),
        .target(
            name: "Logger",
            dependencies: [
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver"),
            ]
        ),
        .target(
            name: "XcodeProjectManagement",
            dependencies: [
                "XcodeProj",
                "Logger"
            ],
            resources: [.copy("README.md")]
        ),
        .executableTarget(
            name: "XcodeProjectCLI",
            dependencies: [
                "XcodeProjectManagement",
                "Logger",
            ]
        ),
        .target(
            name: "XcodeBuildServer",
            dependencies: [
                "JSONRPCConnection",
                "XcodeProjectManagement",
                "Logger",
            ]
        ),
        .executableTarget(
            name: "XcodeBuildServerCLI",
            dependencies: [
                "XcodeBuildServer",
                "Logger",
            ]
        ),
        .testTarget(
            name: "XcodeBuildServerTests",
            dependencies: ["XcodeBuildServer"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "XcodeProjectManagementTests",
            dependencies: ["XcodeProjectManagement"],
            resources: [
                .copy("README.md"),
                .copy("Resources")
            ]
        ),
    ]
)
