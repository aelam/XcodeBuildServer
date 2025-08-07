// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XcodeBuildServer",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "JSONRPCServer",
            targets: ["JSONRPCServer"]
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
    ],
    targets: [
        .target(
            name: "JSONRPCServer",
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
                "Logger"
            ],
            resources: [.copy("README.md")]
        ),
        .target(
            name: "XcodeBuildServer",
            dependencies: [
                "JSONRPCServer",
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
                .copy("DemoProjects")
            ]
        ),
        .testTarget(
            name: "XcodeProjectManagementTests",
            dependencies: ["XcodeProjectManagement"],
            resources: [
                .copy("DemoProjects"),
                .copy("README.md")
            ]
        ),
    ]
)
