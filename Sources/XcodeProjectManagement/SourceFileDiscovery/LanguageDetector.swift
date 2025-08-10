//
//  LanguageDetector.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation

/// Detects programming languages and file types based on file extensions and names
public struct LanguageDetector: Sendable {
    public init() {}

    /// Determine the language and source type of a file
    public func detectLanguageAndType(
        fileExtension: String,
        fileName: String,
        supportedLanguages: Set<String>
    ) -> (language: String, sourceType: SourceFileType)? {
        let lowercaseExtension = fileExtension.lowercased()

        // Swift files
        if lowercaseExtension == "swift" {
            return supportedLanguages.contains("swift") ? ("swift", .source) : nil
        }

        // Objective-C implementation files
        if ["m", "mm"].contains(lowercaseExtension) {
            return supportedLanguages.contains("objective-c") ? ("objective-c", .source) : nil
        }

        // Header files
        if lowercaseExtension == "h" {
            return detectHeaderLanguage(supportedLanguages: supportedLanguages)
        }

        // C files
        if lowercaseExtension == "c" {
            return supportedLanguages.contains("c") ? ("c", .source) : nil
        }

        // C++ implementation files
        if ["cpp", "cc", "cxx", "c++"].contains(lowercaseExtension) {
            return supportedLanguages.contains("cpp") ? ("cpp", .source) : nil
        }

        // C++ header files
        if ["hpp", "hh", "hxx", "h++"].contains(lowercaseExtension) {
            return detectCppHeaderLanguage(supportedLanguages: supportedLanguages)
        }

        // Other file types
        return detectOtherFileTypes(fileExtension: lowercaseExtension)
    }

    /// Check if a file extension is supported for scanning
    public func isSupportedFileExtension(
        _ extension: String,
        supportedLanguages: Set<String>
    ) -> Bool {
        detectLanguageAndType(
            fileExtension: `extension`,
            fileName: "",
            supportedLanguages: supportedLanguages
        ) != nil
    }

    // MARK: - Private Methods

    private func detectHeaderLanguage(
        supportedLanguages: Set<String>
    ) -> (language: String, sourceType: SourceFileType)? {
        let headerSupportedLanguages = ["objective-c", "c", "cpp"]
        let supportedHeaderLanguage = headerSupportedLanguages.first { supportedLanguages.contains($0) }
        return supportedHeaderLanguage.map { ($0, .header) }
    }

    private func detectCppHeaderLanguage(
        supportedLanguages: Set<String>
    ) -> (language: String, sourceType: SourceFileType)? {
        let cppHeaderLanguages = ["cpp", "c"]
        let supportedCppLanguage = cppHeaderLanguages.first { supportedLanguages.contains($0) }
        return supportedCppLanguage.map { ($0, .header) }
    }

    private func detectOtherFileTypes(
        fileExtension: String
    ) -> (language: String, sourceType: SourceFileType)? {
        switch fileExtension {
        case "metal":
            ("metal", .source)
        case "strings", "stringsdict":
            ("strings", .resource)
        case "storyboard", "xib":
            ("interface-builder", .resource)
        case "xcassets":
            ("asset-catalog", .resource)
        case "docc":
            ("documentation", .documentation)
        case "json":
            ("json", .resource)
        case "yaml", "yml":
            ("yaml", .resource)
        case "plist":
            ("plist", .resource)
        default:
            nil
        }
    }
}

/// Extensions for commonly supported file types
public extension LanguageDetector {
    /// All supported source file extensions
    static let sourceFileExtensions: Set<String> = [
        "swift", "m", "mm", "c", "cpp", "cc", "cxx", "c++", "metal"
    ]

    /// All supported header file extensions
    static let headerFileExtensions: Set<String> = [
        "h", "hpp", "hh", "hxx", "h++"
    ]

    /// All supported resource file extensions
    static let resourceFileExtensions: Set<String> = [
        "strings", "stringsdict", "storyboard", "xib", "xcassets",
        "json", "yaml", "yml", "plist"
    ]

    /// All supported documentation file extensions
    static let documentationFileExtensions: Set<String> = [
        "docc"
    ]

    /// All supported file extensions
    static let allSupportedExtensions: Set<String> =
        sourceFileExtensions
            .union(headerFileExtensions)
            .union(resourceFileExtensions)
            .union(documentationFileExtensions)
}
