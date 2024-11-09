// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XcodeBuildServer",
    platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
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
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "XcodeBuildServer",
            dependencies: [
            ]
        ),
        .target(
            name: "XcodeBuildServerCLI"),
        .testTarget(
            name: "XcodeBuildServerTests",
            dependencies: ["XcodeBuildServer"]
        ),
    ]
)
