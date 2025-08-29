import Foundation

// swiftlint:disable:next type_body_length
struct ClangFileBuildSettings: SourceFileBuildConfigurable {
    let targetBuildSettings: TargetBuildSettings
    let sourceFile: String
    let language: XcodeLanguageDialect

    init(targetBuildSettings: TargetBuildSettings, sourceFile: String, language: XcodeLanguageDialect) {
        self.targetBuildSettings = targetBuildSettings
        self.sourceFile = sourceFile
        self.language = language
    }

    // Common computed properties
    var outputFilePath: String {
        targetBuildSettings.buildOutputFilePath(for: sourceFile)
    }

    // Clang-specific computed properties
    var ASTModuleName: String? { nil } // Clang does not use module names in the same way

    var clangASTBuiltProductsDir: String? {
        guard language.isClang else { return nil }
        return targetBuildSettings.moduleName
    }

    var ASTBuiltProductsDir: String {
        guard language.isClang else { return "" }
        return targetBuildSettings.moduleName
    }

    var ASTCommandArguments: [String] {
        guard language.isClang else { return [] }

        var flags: [String] = []

        // Language-specific flag
        if let xclag = language.xflag {
            flags.append(contentsOf: ["-x", xclag])
        }

        // SDK stat cache flags (without -Xcc prefix for direct clang usage)
        flags.append(contentsOf: buildSDKStatCacheFlags())

        // Diagnostic and message flags
        flags.append(contentsOf: buildDiagnosticFlags())

        // Module flags
        flags.append(contentsOf: buildModuleFlags())

        // Warning flags
        flags.append(contentsOf: buildWarningFlags())

        // Optimization and feature flags
        flags.append(contentsOf: buildOptimizationFlags())

        // Preprocessor definitions
        flags.append(contentsOf: buildPreprocessorFlags())

        // Use basic compiler flags from targetBuildSettings
        flags.append(contentsOf: ["-isysroot", targetBuildSettings.sdkRoot])
        flags.append(contentsOf: ["-target", targetBuildSettings.targetTriple])

        // ARC and feature flags
        flags.append(contentsOf: buildClangFlags())

        // Profile and coverage flags
        flags.append(contentsOf: buildProfileFlags())

        // System framework flags for Foundation, UIKit, etc.
        flags.append(contentsOf: buildSystemFrameworkFlags())

        // Header map flags for Clang (without -Xcc prefix)
        flags.append(contentsOf: buildClangHeaderMapFlags())

        flags.append(contentsOf: targetBuildSettings.generalIncludePathFlags)
        flags.append(contentsOf: targetBuildSettings.generalFrameworkPathFlags)
        flags.append(contentsOf: targetBuildSettings.generalWorkingDirectoryFlags)

        // Debug flags (clang-specific, without -Xclang prefix)
        flags.append(contentsOf: buildClangDebugFlags())

        // Output flags (must be at the end)
        let outputName = URL(fileURLWithPath: sourceFile).deletingPathExtension().lastPathComponent
        let outputPath = "/" + [
            targetBuildSettings.projectName + ".build",
            targetBuildSettings.configuration + targetBuildSettings.effectivePlatformName,
            targetBuildSettings.moduleName + ".build",
            "Objects-normal",
            targetBuildSettings.nativeArch,
            outputName + "-\(generateHashForFile()).o"
        ].joined(separator: "/")

        flags.append(contentsOf: [
            "-fsyntax-only",
            sourceFile,
            "-o", outputPath,
            "-index-unit-output-path", outputPath
        ])

        return flags
    }

    // MARK: - Private Clang Flag Building Methods

    private func buildDiagnosticFlags() -> [String] {
        [
            "-fmessage-length=0",
            "-fdiagnostics-show-note-include-stack",
            "-fmacro-backtrace-limit=0",
            "-fno-color-diagnostics"
        ]
    }

    private func buildModuleFlags() -> [String] {
        var flags = [
            "-fmodules-prune-interval=86400",
            "-fmodules-prune-after=345600",
            // "-fno-cxx-modules",
            "-gmodules",
            "-fmodules-cache-path=\(targetBuildSettings.xcodeGlobalSettings.moduleCachePath.path)",
            "-Xclang", "-fmodule-format=raw",
            "-fmodules-validate-system-headers"
        ]

        // Add @import support for Objective-C files (only if modules are enabled)
        if language == .objc || language == .objcCpp,
           targetBuildSettings.buildSettings["CLANG_ENABLE_MODULES"] == "YES" {
            flags.append(contentsOf: [
                // "-Xclang", "-fmodules-autolink",
                // "-Xclang", "-fmodules-decluse"
            ])
        }

        return flags
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func buildClangFlags() -> [String] {
        let settings = targetBuildSettings.buildSettings
        var flags: [String] = []

        // Add user-configured Clang flags from build settings
        if let std = settings["CLANG_CXX_LANGUAGE_STANDARD"] {
            flags.append("-std=\(std)")
        }
        if let std = settings["GCC_C_LANGUAGE_STANDARD"] {
            flags.append("-std=\(std)") // e.g., "gnu11"
        }
        if settings["CLANG_ENABLE_MODULES"] == "YES" {
            flags.append("-fmodules")
        }
        if settings["CLANG_ENABLE_OBJC_ARC"] == "YES" {
            flags.append("-fobjc-arc")
        }
        if settings["CLANG_ENABLE_OBJC_WEAK"] == "YES" {
            flags.append("-fobjc-weak")
        }

        if settings["CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING"] == "YES" {
            flags.append("-Wblock-capture-autoreleasing")
        }

        if settings["CLANG_WARN_BOOL_CONVERSION"] == "YES" {
            flags.append("-Wbool-conversion")
        }
        if settings["CLANG_WARN_COMMA"] == "YES" {
            flags.append("-Wcomma")
        }
        if settings["CLANG_WARN_CONSTANT_CONVERSION"] == "YES" {
            flags.append("-Wconstant-conversion")
        }
        if settings["CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS"] == "YES" {
            flags.append("-Wdeprecated-objc-implementations")
        }
        if settings["CLANG_WARN_DIRECT_OBJC_ISA_USAGE"] == "YES" {
            flags.append("-Wdirect-objc-isa-usage")
        }
        if settings["CLANG_WARN_DOCUMENTATION_COMMENTS"] == "YES" {
            flags.append("-Wdocumentation-comments")
        }
        if settings["CLANG_WARN_EMPTY_BODY"] == "YES" {
            flags.append("-Wempty-body")
        }
        if settings["CLANG_WARN_ENUM_CONVERSION"] == "YES" {
            flags.append("-Wenum-conversion")
        }
        if settings["CLANG_WARN_INFINITE_RECURSION"] == "YES" {
            flags.append("-Winfinite-recursion")
        }
        if settings["CLANG_WARN_INT_CONVERSION"] == "YES" {
            flags.append("-Wint-conversion")
        }
        if settings["CLANG_WARN_NON_LITERAL_NULL_CONVERSION"] == "YES" {
            flags.append("-Wnon-literal-null-conversion")
        }
        if settings["CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF"] == "YES" {
            flags.append("-Wobjc-implicit-retain-self")
        }
        // CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
        if settings["CLANG_WARN_OBJC_LITERAL_CONVERSION"] == "YES" {
            flags.append("-Wobjc-literal-conversion")
        }
        if settings["CLANG_WARN_OBJC_ROOT_CLASS"] == "YES" {
            flags.append("-Wobjc-root-class")
        }
        if settings["CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER"] == "YES" {
            flags.append("-Wquoted-include-in-framework-header")
        }
        if settings["CLANG_WARN_RANGE_LOOP_ANALYSIS"] == "YES" {
            flags.append("-Wrange-loop-analysis")
        }
        if settings["CLANG_WARN_STRICT_PROTOTYPES"] == "YES" {
            flags.append("-Wstrict-prototypes")
        }
        if settings["CLANG_WARN_SUSPICIOUS_MOVE"] == "YES" {
            flags.append("-Wsuspicious-move")
        }
        if settings["CLANG_WARN_UNGUARDED_AVAILABILITY"] == "YES" {
            flags.append("-Wunguarded-availability")
        }
        if settings["CLANG_WARN_UNREACHABLE_CODE"] == "YES" {
            flags.append("-Wunreachable-code")
        }
        if settings["CLANG_WARN__DUPLICATE_METHOD_MATCH"] == "YES" {
            flags.append("-Wduplicate-method-match")
        }

        return flags
    }

    private func buildWarningFlags() -> [String] {
        var flags: [String] = []

        // Add user-configured warning flags from build settings
        if let warningCFlags = targetBuildSettings.buildSettings["WARNING_CFLAGS"] {
            let warningFlags = StringUtils.splitFlags(warningCFlags)
            flags.append(contentsOf: warningFlags)
        }

        // Add C++ specific warning flags if this is a C++ file
        if language == .cpp || language == .objcCpp {
            if let warningCppFlags = targetBuildSettings.buildSettings["WARNING_CPLUSPLUSFLAGS"] {
                let cppWarningFlags = StringUtils.splitFlags(warningCppFlags)
                flags.append(contentsOf: cppWarningFlags)
            }
        }

        // Add specific Clang warning settings that are commonly configured in Xcode
        let clangWarnings = buildClangWarningSettings()
        flags.append(contentsOf: clangWarnings)

        return flags
    }

    private func buildClangWarningSettings() -> [String] {
        var flags: [String] = []

        // Common warning flags that are typically set by Xcode's default configuration
        // These match what you provided in the clang command
        let defaultWarnings = [
            "-Wnon-modular-include-in-framework-module",
            "-Werror=non-modular-include-in-framework-module",
            "-Wno-trigraphs",
            "-Wno-missing-field-initializers",
            "-Wno-missing-prototypes",
            "-Werror=return-type",
            "-Wdocumentation",
            "-Wunreachable-code",
            "-Wquoted-include-in-framework-header",
            "-Wno-implicit-atomic-properties",
            "-Werror=deprecated-objc-isa-usage",
            "-Wno-objc-interface-ivars",
            "-Werror=objc-root-class",
            "-Wno-arc-repeated-use-of-weak",
            "-Wimplicit-retain-self",
            "-Wno-missing-braces",
            "-Wparentheses",
            "-Wswitch",
            "-Wunused-function",
            "-Wno-unused-label",
            "-Wno-unused-parameter",
            "-Wunused-variable",
            "-Wunused-value",
            "-Wuninitialized",
            "-Wconditional-uninitialized",
            "-Wno-unknown-pragmas",
            "-Wno-shadow",
            "-Wno-four-char-constants",
            "-Wno-conversion",
            "-Wno-float-conversion",
            "-Wobjc-literal-conversion",
            "-Wshorten-64-to-32",
            "-Wpointer-sign",
            "-Wno-newline-eof",
            "-Wno-selector",
            "-Wno-strict-selector-match",
            "-Wundeclared-selector",
            "-Wdeprecated-implementations",
            "-Wno-implicit-fallthrough",
            "-Wprotocol",
            "-Wdeprecated-declarations",
            "-Wno-sign-conversion",
            "-Wno-semicolon-before-method-body",
            "-Wunguarded-availability"
        ]

        flags.append(contentsOf: defaultWarnings)
        return flags
    }

    private func buildOptimizationFlags() -> [String] {
        var flags = ["-O0", "-fno-common"]

        // Add strict aliasing
        flags.append("-fstrict-aliasing")

        return flags
    }

    private func buildPreprocessorFlags() -> [String] {
        var flags: [String] = []

        // Add common Objective-C preprocessor definition (only for ObjC files)
        if language == .objc || language == .objcCpp {
            flags.append("-DOBJC_OLD_DISPATCH_PROTOTYPES=0")
        }

        // Add GCC preprocessor definitions from build settings (includes DEBUG=1, etc.)
        let gccFlags = StringUtils.splitFlags(targetBuildSettings.gccPreprocessorDefinitions)
        flags.append(contentsOf: gccFlags)

        return flags
    }

    private func buildProfileFlags() -> [String] {
        [
            "-g",
            "-fprofile-instr-generate",
            "-fcoverage-mapping"
        ]
    }

    private func buildSystemFrameworkFlags() -> [String] {
        var flags: [String] = []

        // Add system frameworks import paths for ObjC files
        if language == .objc || language == .objcCpp {
            let sdkPath = targetBuildSettings.sdkRoot

            // Add system framework search paths
            flags.append(contentsOf: [
                "-iframework", "\(sdkPath)/System/Library/Frameworks",
                "-iframework", "\(sdkPath)/Developer/Library/Frameworks"
            ])

            // Add system headers for @import support
            flags.append(contentsOf: [
                "-isystem", "\(sdkPath)/usr/include",
                "-isystem", "\(sdkPath)/System/Library/Frameworks"
            ])

            // Add system module search paths for better Foundation/UIKit support
            // Only add module map files if they exist
            let frameworkModuleMaps = [
                "\(sdkPath)/System/Library/Frameworks/Foundation.framework/Modules/module.modulemap",
                "\(sdkPath)/System/Library/Frameworks/UIKit.framework/Modules/module.modulemap",
                "\(sdkPath)/System/Library/Frameworks/CoreFoundation.framework/Modules/module.modulemap"
            ]

            for moduleMapPath in frameworkModuleMaps {
                flags.append(contentsOf: ["-fmodule-map-file=\(moduleMapPath)"])
            }

            // Add implicit module maps for system frameworks
            flags.append(contentsOf: [
                "-fimplicit-module-maps",
                "-fbuiltin-module-map"
            ])
        }

        return flags
    }

    private func buildClangHeaderMapFlags() -> [String] {
        let hmapBasePath = targetBuildSettings.clangHmapPath.path
        let moduleName = targetBuildSettings.moduleName

        return [
            "-iquote", "\(hmapBasePath)/\(moduleName)-generated-files.hmap",
            "-I\(hmapBasePath)/\(moduleName)-own-target-headers.hmap",
            "-I\(hmapBasePath)/\(moduleName)-all-target-headers.hmap",
            "-iquote", "\(hmapBasePath)/\(moduleName)-project-headers.hmap"
        ]
    }

    private func buildClangDebugFlags() -> [String] {
        [
            "-fretain-comments-from-system-headers",
            "-detailed-preprocessing-record",
            "-Wno-non-modular-include-in-framework-module",
            "-Wno-incomplete-umbrella",
            "-fmodules-validate-system-headers"
        ]
    }

    private func buildSDKStatCacheFlags() -> [String] {
        // For clang, we don't need -Xcc prefix
        ["-ivfsstatcache", targetBuildSettings.sdkStatCachePath]
    }

    private func generateHashForFile() -> String {
        // Generate a simple hash based on the source file path
        // This mimics Xcode's behavior of generating a hash for each compilation unit
        let sourceFileData = sourceFile.data(using: .utf8) ?? Data()
        let hash = sourceFileData.reduce(0) { $0 &+ Int($1) }
        return String(format: "%08x", hash & 0xFFFF_FFFF)
    }
}
