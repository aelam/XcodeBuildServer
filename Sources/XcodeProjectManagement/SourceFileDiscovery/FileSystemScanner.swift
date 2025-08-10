//
//  FileSystemScanner.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import Logger

/// Scans file system for source files with configurable filtering
public struct FileSystemScanner: Sendable {
    private let languageDetector: LanguageDetector

    public init(languageDetector: LanguageDetector = LanguageDetector()) {
        self.languageDetector = languageDetector
    }

    /// Scan directory for source files
    public func scanSourceFiles(
        in directoryURL: URL,
        targetInfo: XcodeTargetInfo,
        configuration: SourceScanConfiguration = .default
    ) async throws -> [DiscoveredSourceFile] {
        logger.debug("Scanning directory: \(directoryURL.path)")

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            logger.debug("Directory does not exist: \(directoryURL.path)")
            return []
        }

        var discoveredFiles: [DiscoveredSourceFile] = []
        let supportedLanguages = targetInfo.supportedLanguages

        let enumeratorOptions = createEnumeratorOptions(configuration: configuration)
        let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: enumeratorOptions
        )

        var currentDepth = 0

        while let fileURL = enumerator?.nextObject() as? URL {
            // Check depth limit
            if let maxDepth = configuration.maxDepth {
                let relativePath = fileURL.path.replacingOccurrences(of: directoryURL.path, with: "")
                currentDepth = relativePath.components(separatedBy: "/").count - 1

                if currentDepth > maxDepth {
                    continue
                }
            }

            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])

            if let isDirectory = resourceValues.isDirectory, isDirectory {
                // Skip certain directories
                if shouldSkipDirectory(fileURL, configuration: configuration) {
                    enumerator?.skipDescendants()
                }
                continue
            }

            // Check if file passes extension filter
            if let allowedExtensions = configuration.allowedExtensions {
                let fileExtension = fileURL.pathExtension.lowercased()
                if !allowedExtensions.contains(fileExtension) {
                    continue
                }
            }

            // Check if file belongs to this target based on path
            if !isFileForTarget(fileURL: fileURL, targetInfo: targetInfo) {
                continue
            }

            // Check if file is a supported source file
            if let sourceFile = createSourceFile(
                from: fileURL,
                targetInfo: targetInfo,
                supportedLanguages: supportedLanguages
            ) {
                discoveredFiles.append(sourceFile)
            }
        }

        return discoveredFiles
    }

    /// Scan for generated files in derived sources directory
    public func scanGeneratedFiles(
        in directoryURL: URL,
        targetInfo: XcodeTargetInfo
    ) async throws -> [DiscoveredSourceFile] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }

        var generatedFiles: [DiscoveredSourceFile] = []

        let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])

            if let isDirectory = resourceValues.isDirectory, isDirectory {
                continue
            }

            if fileURL.pathExtension.lowercased() == "swift" {
                let generatedFile = DiscoveredSourceFile(
                    url: fileURL,
                    language: "swift",
                    sourceType: .source,
                    isGenerated: true,
                    targetName: targetInfo.name
                )
                generatedFiles.append(generatedFile)
            }
        }

        return generatedFiles
    }

    // MARK: - Private Methods

    private func createEnumeratorOptions(
        configuration: SourceScanConfiguration
    ) -> FileManager.DirectoryEnumerationOptions {
        var options: FileManager.DirectoryEnumerationOptions = []

        if configuration.skipHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        if configuration.skipPackageDirectories {
            options.insert(.skipsPackageDescendants)
        }

        return options
    }

    private func shouldSkipDirectory(
        _ directoryURL: URL,
        configuration: SourceScanConfiguration
    ) -> Bool {
        let lastComponent = directoryURL.lastPathComponent

        // Always skip hidden directories if configured
        if configuration.skipHiddenFiles, lastComponent.hasPrefix(".") {
            return true
        }

        // Skip build directories if configured
        if configuration.skipBuildDirectories {
            let buildDirectories = [
                "build", "Build",
                "DerivedData", ".build",
                "Carthage", "Pods",
                "node_modules"
            ]

            if buildDirectories.contains(lastComponent) {
                return true
            }
        }

        // Skip package directories if configured
        if configuration.skipPackageDirectories {
            let packageDirectories = [".swiftpm"]

            if packageDirectories.contains(lastComponent) {
                return true
            }
        }

        return false
    }

    /// Determine if a file belongs to a specific target based on path patterns
    private func isFileForTarget(fileURL: URL, targetInfo: XcodeTargetInfo) -> Bool {
        let filePath = fileURL.path
        let targetName = targetInfo.name
        let fileName = fileURL.lastPathComponent

        // Test targets - should only include files from test directories
        if targetName.hasSuffix("Tests") || targetName.hasSuffix("UITests") {
            // Check for test target directory or test file patterns
            let testPatterns = [
                "/\(targetName)/", // e.g., /HelloTests/
                "/\(targetName).swift", // e.g., /HelloTests.swift
                "\(targetName).swift" // e.g., HelloTests.swift (filename match)
            ]

            return testPatterns.contains { pattern in
                filePath.contains(pattern)
            } || fileName == "\(targetName).swift" // Direct filename match
        }

        // Regular targets - be more specific about what belongs to each target
        // 1. Exclude all test files first
        let excludePatterns = [
            "Tests/",
            "UITests/",
            "Tests.swift",
            "UITests.swift"
        ]

        for pattern in excludePatterns where filePath.contains(pattern) {
            return false
        }

        // 2. For specific target directories, include files from that directory
        if filePath.contains("/\(targetName)/") {
            return true
        }

        // 3. For files that match the target name pattern
        if fileName.hasPrefix(targetName), !fileName.hasSuffix("Tests.swift") {
            return true
        }

        // 3. For root-level files, only include them in the main target (usually the first one)
        // Exclude project-wide config files from individual targets
        let projectWideFiles = [
            "buildServer.json",
            "hello.json",
            ".gitignore",
            "Package.swift",
            "README.md"
        ]

        if projectWideFiles.contains(fileName) {
            // Only include project-wide files in the main target (usually the one matching project name)
            // You can adjust this logic based on your project structure
            return targetName == "Hello" // Adjust this to match your main target name
        }

        // 4. App-specific files should only be in their respective targets
        if fileName.contains("App.swift") {
            // HelloApp.swift should only be in Hello target
            // WorldApp.swift should only be in World target
            let appTargetName = fileName.replacingOccurrences(of: "App.swift", with: "")
            return appTargetName == targetName
        }

        return false
    }

    private func createSourceFile(
        from fileURL: URL,
        targetInfo: XcodeTargetInfo,
        supportedLanguages: Set<String>
    ) -> DiscoveredSourceFile? {
        let fileExtension = fileURL.pathExtension.lowercased()
        let fileName = fileURL.lastPathComponent

        // Determine file language and type
        guard let (language, sourceType) = languageDetector.detectLanguageAndType(
            fileExtension: fileExtension,
            fileName: fileName,
            supportedLanguages: supportedLanguages
        ) else {
            return nil
        }

        return DiscoveredSourceFile(
            url: fileURL,
            language: language,
            sourceType: sourceType,
            isGenerated: false,
            targetName: targetInfo.name
        )
    }
}
