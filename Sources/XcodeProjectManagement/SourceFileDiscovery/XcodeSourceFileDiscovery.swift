////
////  XcodeSourceFileDiscovery.swift
////
////  Copyright © 2024 Wang Lun.
////
//
// import Foundation
// import Logger
//
///// Main coordinator for discovering source files in Xcode projects
// public struct XcodeSourceFileDiscovery: Sendable {
//    private let pathResolver: SourcePathResolver
//    private let fileSystemScanner: FileSystemScanner
//    private let bspConverter: BSPSourceItemConverter
//
//    public init(
//        pathResolver: SourcePathResolver = SourcePathResolver(),
//        fileSystemScanner: FileSystemScanner = FileSystemScanner(),
//        bspConverter: BSPSourceItemConverter = BSPSourceItemConverter()
//    ) {
//        self.pathResolver = pathResolver
//        self.fileSystemScanner = fileSystemScanner
//        self.bspConverter = bspConverter
//    }
//
//    /// Discover source files for a specific target
//    public func discoverSourceFiles(
//        for targetInfo: XcodeTargetInfo,
//        projectInfo: XcodeProjectInfo,
//        configuration: SourceScanConfiguration = .default
//    ) async throws -> [DiscoveredSourceFile] {
//        logger.debug("Discovering source files for target: \(targetInfo.name)")
//
//        var discoveredFiles: [DiscoveredSourceFile] = []
//
//        // 1. Get source paths from build settings
//        let sourcePaths = pathResolver.extractSourcePaths(
//            from: targetInfo.buildSettings,
//            projectInfo: projectInfo
//        )
//        logger.debug("Found \(sourcePaths.count) source paths from build settings")
//
//        // 2. Scan file system for source files
//        for sourcePath in sourcePaths {
//            let filesInPath = try await fileSystemScanner.scanSourceFiles(
//                in: sourcePath,
//                targetInfo: targetInfo,
//                configuration: configuration
//            )
//            discoveredFiles.append(contentsOf: filesInPath)
//        }
//
//        // 3. Add generated files from derived data
//        let generatedFiles = try await findGeneratedFiles(for: targetInfo, projectInfo: projectInfo)
//        discoveredFiles.append(contentsOf: generatedFiles)
//
//        // 4. Remove duplicates based on file URL
//        discoveredFiles = removeDuplicates(discoveredFiles)
//
//        logger.debug("Discovered \(discoveredFiles.count) total source files for target \(targetInfo.name)")
//        return discoveredFiles
//    }
//
//    /// Get root directories that should be used as source roots
//    public func getSourceRoots(
//        for targetInfo: XcodeTargetInfo,
//        projectInfo: XcodeProjectInfo
//    ) -> [URL] {
//        pathResolver.getSourceRoots(for: targetInfo, projectInfo: projectInfo)
//    }
//
//    /// Convert discovered files to BSP format
//    public func convertToBSPFormat(
//        _ sourceFiles: [DiscoveredSourceFile]
//    ) -> [SourceItemConversionResult] {
//        bspConverter.convertMultiple(sourceFiles)
//    }
//
//    /// Get statistics about discovered source files
//    public func getStatistics(
//        _ sourceFiles: [DiscoveredSourceFile]
//    ) -> SourceFileStatistics {
//        bspConverter.getStatistics(sourceFiles)
//    }
//
//    /// Discover source files for multiple targets
//    public func discoverSourceFilesForTargets(
//        _ targets: [XcodeTargetInfo],
//        projectInfo: XcodeProjectInfo,
//        configuration: SourceScanConfiguration = .default
//    ) async throws -> [String: [DiscoveredSourceFile]] {
//        var results: [String: [DiscoveredSourceFile]] = [:]
//
//        for target in targets {
//            let sourceFiles = try await discoverSourceFiles(
//                for: target,
//                projectInfo: projectInfo,
//                configuration: configuration
//            )
//            results[target.name] = sourceFiles
//        }
//
//        return results
//    }
//
//    // MARK: - Private Methods
//
//    private func findGeneratedFiles(
//        for targetInfo: XcodeTargetInfo,
//        projectInfo: XcodeProjectInfo
//    ) async throws -> [DiscoveredSourceFile] {
//        var generatedFiles: [DiscoveredSourceFile] = []
//
//        // Look for generated files in derived sources directory
//        if let derivedSourcesURL = pathResolver.getDerivedSourcesDirectory(
//            from: targetInfo.buildSettings
//        ) {
//            let derivedFiles = try await fileSystemScanner.scanGeneratedFiles(
//                in: derivedSourcesURL,
//                targetInfo: targetInfo
//            )
//            generatedFiles.append(contentsOf: derivedFiles)
//        }
//
//        return generatedFiles
//    }
//
//    private func removeDuplicates(_ sourceFiles: [DiscoveredSourceFile]) -> [DiscoveredSourceFile] {
//        var seen = Set<URL>()
//        return sourceFiles.filter { sourceFile in
//            if seen.contains(sourceFile.url) {
//                return false
//            } else {
//                seen.insert(sourceFile.url)
//                return true
//            }
//        }
//    }
// }
//
///// Convenience extensions for common use cases
// public extension XcodeSourceFileDiscovery {
//    /// Quick discovery with default configuration
//    static func discover(
//        target: XcodeTargetInfo,
//        project: XcodeProjectInfo
//    ) async throws -> [DiscoveredSourceFile] {
//        let discovery = XcodeSourceFileDiscovery()
//        return try await discovery.discoverSourceFiles(for: target, projectInfo: project)
//    }
//
//    /// Discover only Swift source files
//    func discoverSwiftFiles(
//        for targetInfo: XcodeTargetInfo,
//        projectInfo: XcodeProjectInfo
//    ) async throws -> [DiscoveredSourceFile] {
//        let configuration = SourceScanConfiguration(
//            allowedExtensions: ["swift"]
//        )
//
//        let allFiles = try await discoverSourceFiles(
//            for: targetInfo,
//            projectInfo: projectInfo,
//            configuration: configuration
//        )
//
//        return allFiles.filter { $0.language == "swift" }
//    }
//
//    /// Discover only header files
//    func discoverHeaderFiles(
//        for targetInfo: XcodeTargetInfo,
//        projectInfo: XcodeProjectInfo
//    ) async throws -> [DiscoveredSourceFile] {
//        let allFiles = try await discoverSourceFiles(for: targetInfo, projectInfo: projectInfo)
//        return bspConverter.filterByType(allFiles, type: .header)
//    }
// }
