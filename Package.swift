// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XcodeBuildServer",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "XcodeBuildServer",
            targets: ["XcodeBuildServer"]
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
    ],
    targets: [
        .target(
            name: "XcodeBuildServer",
            dependencies: [
            ]
        ),
        .executableTarget(
            name: "XcodeBuildServerCLI",
            dependencies: [
                "XcodeBuildServer",
            ]
        ),
        .testTarget(
            name: "XcodeBuildServerTests",
            dependencies: ["XcodeBuildServer"],
            resources: [.copy("../../DemoProjects")]
        ),
    ]
)
