/// PBXProject (工程)
/// │
/// ├─ XCConfigurationList (配置列表)
/// │   ├─ XCBuildConfiguration "Debug"
/// │   │    └─ buildSettings { ... }   ← 工程 Debug 配置
/// │   └─ XCBuildConfiguration "Release"
/// │        └─ buildSettings { ... }   ← 工程 Release 配置
/// │
/// └─ PBXNativeTarget "AppTarget"
///     │
///     └─ XCConfigurationList (配置列表)
///         ├─ XCBuildConfiguration "Debug"
///         │    └─ buildSettings { ... }  ← Target Debug 配置（覆盖 Project Debug）
///         └─ XCBuildConfiguration "Release"
///              └─ buildSettings { ... }  ← Target Release 配置（覆盖 Project Release）

import Foundation
import PathKit
import XcodeProj

/// 通用 Xcode Build Setting 解析器。支持递归查找、$(inherited) 合并、自定义默认值。
struct BuildSettingResolver: @unchecked Sendable {
    let xcodeGlobalSettings: XcodeGlobalSettings
    let xcodeProj: XcodeProj
    let target: String
    let configuration: String
    let overrides: [String: String]
    private let sourceRoot: Path?

    init(
        xcodeGlobalSettings: XcodeGlobalSettings,
        xcodeProj: XcodeProj,
        target: String,
        configuration: String = "Debug",
        overrides: [String: String] = [:]
    ) {
        self.xcodeGlobalSettings = xcodeGlobalSettings
        self.xcodeProj = xcodeProj
        self.target = target
        self.configuration = configuration
        self.overrides = overrides
        self.sourceRoot = xcodeProj.path?.parent()
    }

    func resolve(forKey key: String) -> String? {
        guard
            let project = xcodeProj.pbxproj.projects.first,
            let xcodeProjTarget = xcodeProj.pbxproj.nativeTargets.first(where: { $0.name == target })
        else {
            return nil
        }

        // 1. Custom overrides
        let customVal = overrides[key]

        // 2. Target-level
        let targetVal = getBuildSettingsFromConfigList(
            xcodeProjTarget.buildConfigurationList,
            configurationName: configuration,
            key: key
        )

        // 3. Project-level
        let projectVal = getBuildSettingsFromConfigList(
            project.buildConfigurationList,
            configurationName: configuration,
            key: key
        )

        // 4. global-level
        let globalDefault = BuildSettingResolver.defaultFor(key: key)

        // merge $inherit
        return expandInherited(
            customVal,
            parent: expandInherited(
                targetVal,
                parent: expandInherited(projectVal, parent: customVal ?? globalDefault)
            )
        )
    }

    private func getBuildSettingsFromConfigList(
        _ configList: XCConfigurationList?,
        configurationName: String,
        key: String
    ) -> String? {
        configList?.buildConfigurations.first { $0.name == configurationName }?.buildSettings[key] as? String
    }

    private func expandInherited(_ value: String?, parent: String?) -> String? {
        guard let value, !value.isEmpty else { return parent }
        if value.contains("$(inherited)") {
            let replaced = value.replacingOccurrences(of: "$(inherited)", with: parent ?? "")
            return replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    static func defaultFor(key: String) -> String? {
        switch key {
        case "SDKROOT": "iphonesimulator"
        case "ARCHS": "arm64"
        case "PLATFORM_NAME": "iphonesimulator"
        case "IPHONEOS_DEPLOYMENT_TARGET": "18.0"
        case "SWIFT_VERSION": "5.0"
        default: nil
        }
    }
}

extension BuildSettingResolver {
    func resolveFileCompilerFlags(
        for fileURL: URL
    ) -> [String]? {
        guard
            let xcodeProjTarget = xcodeProj.pbxproj.nativeTargets.first(where: { $0.name == target })
        else {
            return nil
        }
        guard let sourceRoot else { return nil }

        // === Old: PBXBuildFile.settings.COMPILER_FLAGS ===
        let oldFlags = resolveOldFileFlags(for: fileURL, sourceRoot: sourceRoot)
        if !oldFlags.isEmpty {
            return oldFlags
        }

        // === New: PBXFileSystemSynchronizedRootGroup → exceptions → BuildFileExceptionSet ===
        // === Xcode15+: PBXFileSystemSynchronizedBuildFileExceptionSet ===
        return resolveNewFileFlags(for: fileURL, target: xcodeProjTarget, sourceRoot: sourceRoot)
    }

    private func resolveOldFileFlags(for fileURL: URL, sourceRoot: Path) -> [String] {
        var flags: [String] = []
        for buildFile in xcodeProj.pbxproj.buildFiles {
            guard let file = buildFile.file else { continue }
            if let absPath = try? file.fullPath(sourceRoot: sourceRoot),
               absPath.url == fileURL,
               let settings = buildFile.settings,
               let compilerFlags = settings["COMPILER_FLAGS"] as? String {
                flags += compilerFlags.split(separator: " ").map { String($0) }
            }
        }
        return flags
    }

    private func resolveNewFileFlags(for fileURL: URL, target: PBXNativeTarget, sourceRoot: Path) -> [String] {
        var flags: [String] = []
        for rootGroup in target.fileSystemSynchronizedGroups ?? [] {
            for exception in rootGroup.exceptions ?? [] {
                guard
                    let exceptionSet = exception as? PBXFileSystemSynchronizedBuildFileExceptionSet,
                    let groupPath = rootGroup.path
                else { continue }

                for (relativePath, compilerFlags) in exceptionSet.additionalCompilerFlagsByRelativePath ?? [:] {
                    let absPath = sourceRoot + groupPath + relativePath
                    if absPath.url == fileURL {
                        flags += compilerFlags.split(separator: " ").map { String($0) }
                    }
                }
            }
        }
        return flags
    }
}
