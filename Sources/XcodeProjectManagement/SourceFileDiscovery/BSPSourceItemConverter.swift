////
////  BSPSourceItemConverter.swift
////
////  Copyright © 2024 Wang Lun.
////
//
// import Foundation
//
///// Converts DiscoveredSourceFile to BSP SourceItem format
// public struct BSPSourceItemConverter: Sendable {
//    public init() {}
//
//    /// Convert discovered source file to BSP format
//    public func convertToSourceItem(_ sourceFile: DiscoveredSourceFile) -> SourceItemConversionResult {
//        let uri = sourceFile.url.absoluteString
//        let kind = sourceFile.sourceType == .source || sourceFile.sourceType == .header ? 1 : 2 // file vs directory
//
//        // Create SourceKit data
//        var sourceKitData: [String: String] = [
//            "language": sourceFile.language
//        ]
//
//        // Add source kind for SourceKit
//        switch sourceFile.sourceType {
//        case .source:
//            sourceKitData["kind"] = "source"
//        case .header:
//            sourceKitData["kind"] = "header"
//        case .documentation:
//            sourceKitData["kind"] = "doccCatalog"
//        case .resource:
//            // Use specific kinds for different resource types
//            if sourceFile.language == "json" {
//                sourceKitData["kind"] = "resource"
//            } else if sourceFile.language == "asset-catalog" {
//                sourceKitData["kind"] = "resource"
//            } else {
//                sourceKitData["kind"] = "resource"
//            }
//        }
//
//        return SourceItemConversionResult(
//            uri: uri,
//            kind: kind,
//            generated: sourceFile.isGenerated,
//            dataKind: "sourceKit",
//            data: sourceKitData
//        )
//    }
//
//    /// Convert multiple discovered source files to BSP format
//    public func convertMultiple(_ sourceFiles: [DiscoveredSourceFile]) -> [SourceItemConversionResult] {
//        sourceFiles.map { convertToSourceItem($0) }
//    }
//
//    /// Group source files by target
//    public func groupByTarget(_ sourceFiles: [DiscoveredSourceFile]) -> [String: [DiscoveredSourceFile]] {
//        Dictionary(grouping: sourceFiles) { $0.targetName }
//    }
//
//    /// Filter source files by type
//    public func filterByType(_ sourceFiles: [DiscoveredSourceFile], type: SourceFileType) -> [DiscoveredSourceFile] {
//        sourceFiles.filter { $0.sourceType == type }
//    }
//
//    /// Filter source files by language
//    public func filterByLanguage(_ sourceFiles: [DiscoveredSourceFile], language: String) -> [DiscoveredSourceFile] {
//        sourceFiles.filter { $0.language == language }
//    }
//
//    /// Get statistics about discovered source files
//    public func getStatistics(_ sourceFiles: [DiscoveredSourceFile]) -> SourceFileStatistics {
//        let totalFiles = sourceFiles.count
//        let generatedFiles = sourceFiles.filter(\.isGenerated).count
//
//        let languageCounts = Dictionary(
//            sourceFiles.map { ($0.language, 1) },
//            uniquingKeysWith: +
//        )
//
//        let typeCounts = Dictionary(
//            sourceFiles.map { ($0.sourceType, 1) },
//            uniquingKeysWith: +
//        )
//
//        return SourceFileStatistics(
//            totalFiles: totalFiles,
//            generatedFiles: generatedFiles,
//            sourceFiles: totalFiles - generatedFiles,
//            languageCounts: languageCounts,
//            typeCounts: typeCounts
//        )
//    }
// }
//
///// Statistics about discovered source files
// public struct SourceFileStatistics: Sendable {
//    public let totalFiles: Int
//    public let generatedFiles: Int
//    public let sourceFiles: Int
//    public let languageCounts: [String: Int]
//    public let typeCounts: [SourceFileType: Int]
//
//    public init(
//        totalFiles: Int,
//        generatedFiles: Int,
//        sourceFiles: Int,
//        languageCounts: [String: Int],
//        typeCounts: [SourceFileType: Int]
//    ) {
//        self.totalFiles = totalFiles
//        self.generatedFiles = generatedFiles
//        self.sourceFiles = sourceFiles
//        self.languageCounts = languageCounts
//        self.typeCounts = typeCounts
//    }
// }
//
///// Extension for adding convenience methods to DiscoveredSourceFile
// public extension DiscoveredSourceFile {
//    /// Convert to BSP format using default converter
//    func toBSPFormat() -> SourceItemConversionResult {
//        let converter = BSPSourceItemConverter()
//        return converter.convertToSourceItem(self)
//    }
//
//    /// Check if file matches a pattern
//    func matches(pattern: String) -> Bool {
//        let fileName = url.lastPathComponent
//        return fileName.range(of: pattern, options: .regularExpression) != nil
//    }
//
//    /// Get relative path from a base URL
//    func relativePath(from baseURL: URL) -> String {
//        if let relativePath = url.relativePath(from: baseURL) {
//            return relativePath
//        }
//        return url.path
//    }
// }
//
///// Extension for URL to get relative paths
// private extension URL {
//    func relativePath(from baseURL: URL) -> String? {
//        // Ensure both URLs are file URLs
//        guard self.isFileURL, baseURL.isFileURL else {
//            return nil
//        }
//
//        let basePath = baseURL.standardized.path
//        let fullPath = self.standardized.path
//
//        // Check if the full path starts with the base path
//        if fullPath.hasPrefix(basePath) {
//            let startIndex = fullPath.index(fullPath.startIndex, offsetBy: basePath.count)
//            var relativePath = String(fullPath[startIndex...])
//
//            // Remove leading slash if present
//            if relativePath.hasPrefix("/") {
//                relativePath = String(relativePath.dropFirst())
//            }
//
//            return relativePath.isEmpty ? "." : relativePath
//        }
//
//        return nil
//    }
// }
