// swift-tools-version: 5.10
import PackageDescription

let swiftlintVersion: Version = "0.60.0"
let swiftformatVersion: Version = "0.57.2"

let package = Package(
    name: "Tools",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint.git", exact: swiftlintVersion),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", exact: swiftformatVersion),
    ],
    targets: [
    ]
)
