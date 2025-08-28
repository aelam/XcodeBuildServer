//
//  BuildSettingKey.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/08/26.
//

import Foundation
import XcodeProj

enum BuildSettingKey: String {
    // MARK: - CLANG

    case clangAnalyzerNumberObjectConversion = "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION" // YES_AGGRESSIVE;
    case clangAnalyzerNonnull = "CLANG_ANALYZER_NONNULL"
    case clangCXXLanuageStandard = "CLANG_CXX_LANGUAGE_STANDARD" // = "gnu++14";
    case clangEnableObjWeak = "CLANG_ENABLE_OBJC_WEAK" // = YES;
    case clangEnableModules = "CLANG_ENABLE_MODULES"
    case clangEnableObjArc = "CLANG_ENABLE_OBJC_ARC"

    // MARK: - CLANG WARN

    case clangWarnConstantConversion = "CLANG_WARN_CONSTANT_CONVERSION"
    case clangWarnDuplicateMethodMatch = "CLANG_WARN__DUPLICATE_METHOD_MATCH"
    case clangWarnEmptyBody = "CLANG_WARN_EMPTY_BODY"
    case clangWarnEnumConversion = "CLANG_WARN_ENUM_CONVERSION"
    case clangWarnInifiniteRecursion = "CLANG_WARN_INFINITE_RECURSION"
    case clangWarnNonLiteralNullConversion = "CLANG_WARN_NON_LITERAL_NULL_CONVERSION"
    case clangWarnObjCRootClass = "CLANG_WARN_OBJC_ROOT_CLASS"
    case clangWarnObjCImplicitRetainSelf = "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF"
    case clangWarnQuotedIncludeInFrameworkHeader = "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER"
    case clangWarnStrictProtoptypes = "CLANG_WARN_STRICT_PROTOTYPES"
    case clangWarnSuspiciousMove = "CLANG_WARN_SUSPICIOUS_MOVE"
    case clangWarnUngardedAvailability = "CLANG_WARN_UNGUARDED_AVAILABILITY"
    case clangWarnDocumentationComments = "CLANG_WARN_DOCUMENTATION_COMMENTS"
    case clangWarnBlockCaptureAutoreleasing = "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING"
    case clangWarnRangeLoopAnalysis = "CLANG_WARN_RANGE_LOOP_ANALYSIS"

    // MARK: - GCC

    case gccCLanguageStandard = "GCC_C_LANGUAGE_STANDARD" // = gnu11;
    case gccNoCommonBlocks = "GCC_NO_COMMON_BLOCKS"

    // MARK: - GCC warning

    case gccWarnDeprecatedObjcImplementation = "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS"
    case gccWarnUnusedFunction = "GCC_WARN_UNUSED_FUNCTION"
    case gccWarnUnusedVariable = "GCC_WARN_UNUSED_VARIABLE"
    case gccWarnUnitializedAutos = "GCC_WARN_UNINITIALIZED_AUTOS"
    case gccWarnUndeclaredSelector = "GCC_WARN_UNDECLARED_SELECTOR"

    // MARK: - swift

    case swiftVersion = "SWIFT_VERSION" // 5.0
    case swiftCompilationMode = "SWIFT_COMPILATION_MODE" // "wholemodule"
    case swiftObjCBridgingHeader = "SWIFT_OBJC_BRIDGING_HEADER" // World/World1-Bridging-Header.h
    case productName = "PRODUCT_NAME"
    case sdkRoot = "SDKROOT" // = iphoneos;

    case enableModuleVerifier = "ENABLE_MODULE_VERIFIER"
    case alwaysSearchUserPaths = "ALWAYS_SEARCH_USER_PATHS" // NO
    case infoPlistFile = "INFOPLIST_FILE" // = UserStickersShareExtension/Info.plist;
    case ldRunPathSearchPaths =
        "LD_RUNPATH_SEARCH_PATHS" // = ( "$(inherited)", "@executable_path/Frameworks",
    // "@executable_path/../../Frameworks",);
    case productBundleIdentifier = "PRODUCT_BUNDLE_IDENTIFIER" // = com.linecorp.creatorsstudio.shareextension;
}

struct BuildSettingsResolver {
    let xcodeProjectBuildSettings: XcodeProjectProjectBuildSettings
    let xcodeProj: XcodeProj

    func value(
        for key: String,
        configuration: String = "Debug",
        fileURL: URL?
    ) -> String {
        ""
    }

    private func value(
        for key: String,
        configuration: String,
        targetBuildSettings: [String: String],
        projectBuildSettings: [String: String]
    ) -> String? {
        ""
    }

    private func value(
        for key: String,
        configuration: String,
        target: PBXTarget
    ) -> String? {
        var value: String?
        if let config = target.buildConfigurationList?.configuration(name: configuration) {
            value = config.buildSettings[key] as? String
        }
        return value
    }

    private func value(
        for key: String,
        configuration: String,
        project: PBXTarget
    ) -> String? {
        ""
    }
}
