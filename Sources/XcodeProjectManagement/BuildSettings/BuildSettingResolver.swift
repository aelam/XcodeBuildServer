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
///              └─ buildSettings { ... }  ← Target Release 配置（覆盖 Project
/// Release）

import Foundation
import PathKit
import XcodeProj

/// 通用 Xcode Build Setting 解析器。支持递归查找、$(inherited) 合并、自定义默认值。
struct BuildSettingResolver: @unchecked Sendable {
    enum ResolverError: Error {
        case invalidXcodeProj
        case targetNotFound(String)
        case configurationNotFound(String)
    }

    let xcodeInstallation: XcodeInstallation
    let xcodeGlobalSettings: XcodeGlobalSettings
    let xcodeProj: XcodeProj
    let target: String
    let configuration: String
    let overrides: [String: String]
    let forceSimulator: Bool
    // private
    private let sourceRoot: Path
    private let project: PBXProject
    private let xcodeProjTarget: PBXNativeTarget
    let resolvedBuildSettings: [String: String]

    init(
        xcodeInstallation: XcodeInstallation,
        xcodeGlobalSettings: XcodeGlobalSettings,
        xcodeProj: XcodeProj,
        target: String,
        configuration: String = "Debug",
        overrides: [String: String] = [:],
        forceSimulator: Bool = true
    ) throws {
        self.xcodeInstallation = xcodeInstallation
        self.xcodeGlobalSettings = xcodeGlobalSettings
        self.xcodeProj = xcodeProj
        self.target = target
        self.configuration = configuration
        self.overrides = overrides
        self.forceSimulator = forceSimulator

        guard
            let sourceRoot = xcodeProj.path?.parent(),
            let project = xcodeProj.pbxproj.projects.first,
            let xcodeProjTarget = xcodeProj.pbxproj.nativeTargets
            .first(where: { $0.name == target })
        else {
            throw ResolverError.invalidXcodeProj
        }

        self.sourceRoot = sourceRoot
        self.project = project
        self.xcodeProjTarget = xcodeProjTarget
        self.resolvedBuildSettings = Self.resolveBuildSettings(
            xcodeInstallation: xcodeInstallation,
            sourceRoot: sourceRoot,
            project: project,
            target: xcodeProjTarget,
            configuration: configuration,
            xcodeGlobalSettings: xcodeGlobalSettings,
            overrides: overrides,
            forceSimulator: forceSimulator
        )
    }

    func resolve(forKey key: String) -> String? {
        resolvedBuildSettings[key] ?? defaultFor(key: key)
    }

    private func getBuildSettingsFromConfigList(
        _ configList: XCConfigurationList?,
        configurationName: String,
        key: String
    ) -> String? {
        configList?.buildConfigurations.first { $0.name == configurationName }?
            .buildSettings[key] as? String
    }

    private func defaultFor(key: String) -> String? {
        switch key {
        case BuildSettingKey.toolchains.rawValue: "com.apple.dt.toolchain.XcodeDefault"
        case BuildSettingKey.buildVariants.rawValue: "normal"
        default: nil
        }
    }

    // swiftlint:disable:next function_parameter_count
    private static func resolveBuildSettings(
        xcodeInstallation: XcodeInstallation,
        sourceRoot: Path,
        project: PBXProject,
        target: PBXNativeTarget,
        configuration: String,
        xcodeGlobalSettings: XcodeGlobalSettings,
        overrides: [String: String],
        forceSimulator: Bool
    ) -> [String: String] {
        let projectBuildSettings = project.buildConfigurationList?
            .buildConfigurations
            .first { $0.name == configuration }?.buildSettings
        var targetBuildSettings = target.buildConfigurationList?
            .buildConfigurations
            .first { $0.name == configuration }?.buildSettings

        // determine SDK
        let sdk: String = targetBuildSettings?["SDKROOT"] as? String
            ?? projectBuildSettings?["SDKROOT"] as? String
            ?? "iphonesimulator" // ,

        let defaultBuildSettings = PlatformDefaults.settings(
            for: sdk,
            configuration: configuration,
            xcode: xcodeInstallation,
            forceSimulator: forceSimulator
        )

        if targetBuildSettings?["TARGET_NAME"] == nil {
            targetBuildSettings?["TARGET_NAME"] = target.name
        }

        let autoFix: [String: String] = ["CONFIGURATION": configuration]

        // 1. project-level
        // 2. target-level
        // 3. auto fix
        // 4. custom overrides

        var result = mergeSettings(
            layers: [
                defaultBuildSettings,
                normalizeSettings(projectBuildSettings ?? [:]),
                normalizeSettings(targetBuildSettings ?? [:]),
                autoFix,
                overrides
            ]
        )

        let moduleName = result["PRODUCT_NAME"]?.asRFC1034Identifier() ?? target.name.asRFC1034Identifier()
        let actualSDK = result["PLATFORM_NAME"] ?? sdk
        result["PROJECT"] = project.name
        result["SDKROOT"] = result["SDKROOT_PATH"]
        result["PRODUCT_MODULE_NAME"] = moduleName
        result["SYMROOT"] = xcodeGlobalSettings.symRoot.path
        result["CONFIGURATION_BUILD_DIR"] = xcodeGlobalSettings.derivedDataPath
            .appendingPathComponent("Build/Products")
            .appendingPathComponent(configuration + "-" + actualSDK)
            .path
        result["CONFIGURATION_TEMP_DIR"] = xcodeGlobalSettings.derivedDataPath
            .appendingPathComponent("Build/Intermediates.noindex")
            .appendingPathComponent(project.name + ".build")
            .appendingPathComponent(configuration + "-" + actualSDK)
            .appendingPathComponent(moduleName + ".build")
            .path
        result["PROJECT_GUID"] = project.uuid
        result["SRCROOT"] = sourceRoot.string

        return result
    }

    private static func normalizeSettings(_ settings: [String: Any])
        -> [String: String] {
        var dict: [String: String] = [:]
        for (key, value) in settings {
            if let str = value as? String {
                dict[key] = str
            } else if let arr = value as? [String] {
                dict[key] = arr.joined(separator: " ")
            }
        }
        return dict
    }

    /// 按层级合并 + 展开（先无 $ 的 key，后依赖项；无 globals）
    private static func mergeSettings(layers: [[String: String]]) -> [String: String] {
        // 1) 先做原始合并，只展开 $(inherited)
        var raw: [String: String] = [:]
        for overlay in layers {
            for (key, newVal) in overlay {
                let parent = raw[key]
                raw[key] = expandInheritedOnly(newVal, parent: parent)
            }
        }

        // 2) 再做变量展开：先无 $ 的 key，后依赖 key，直至收敛
        return resolveAllVariables(raw)
    }

    // MARK: - Phase 1: only $(inherited)

    /// 仅展开 $(inherited)，不展开 $(VAR)
    private static func expandInheritedOnly(_ value: String, parent: String?) -> String {
        guard value.contains("$(inherited)") else { return value }
        let replacement = parent ?? ""
        return value.replacingOccurrences(of: "$(inherited)", with: replacement)
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Phase 2: expand $(VAR) with ordering

    /// 先落无 `$(` 的键，再迭代替换有依赖的键
    private static func resolveAllVariables(_ raw: [String: String], maxRounds: Int = 10) -> [String: String] {
        var resolved: [String: String] = [:]
        var pending: [String: String] = [:]

        // 2.1 seed：不含 `$(` 的先放入 resolved，其余进 pending
        for (k, v) in raw {
            if v.contains("$(") {
                pending[k] = v
            } else {
                resolved[k] = v
            }
        }

        // 2.2 多轮替换，直到没有进展或达到上限
        var round = 0
        while !pending.isEmpty, round < maxRounds {
            round += 1
            var stillPending: [String: String] = [:]
            var progressed = false

            for (k, v) in pending {
                let newV = expandVarsFast(v, using: resolved)
                if newV.contains("$(") {
                    // 还有未解析的占位符，下轮再试
                    stillPending[k] = newV
                } else {
                    // 已解析完成，落入 resolved
                    resolved[k] = newV
                    progressed = true
                }
            }

            pending = stillPending
            if !progressed { break } // 无进展，避免死循环
        }

        // 2.3 兜底：还含 `$(` 的，最后再用已解析值做一次替换（无法解析的变量置空）
        for (k, v) in pending {
            resolved[k] = expandVarsFast(v, using: resolved, replaceUnknownWithEmpty: true)
        }

        return resolved
    }

    /// 快速展开 $(KEY)；仅使用 `known` 里的已解析值
    private static func expandVarsFast(
        _ value: String,
        using known: [String: String],
        replaceUnknownWithEmpty: Bool = false
    ) -> String {
        guard value.contains("$(") else { return value }
        var out = ""
        var i = value.startIndex

        while i < value.endIndex {
            if value[i] == "$",
               value.index(after: i) < value.endIndex,
               value[value.index(after: i)] == "(" {
                var j = value.index(i, offsetBy: 2)
                var name = ""
                while j < value.endIndex, value[j] != ")" {
                    name.append(value[j])
                    j = value.index(after: j)
                }

                if j < value.endIndex { // 命中闭合 ')'
                    let rep = known[name] ?? (replaceUnknownWithEmpty ? "" : "$(\(name))")
                    out.append(rep)
                    i = value.index(after: j)
                    continue
                }
            }
            out.append(value[i])
            i = value.index(after: i)
        }

        return out.trimmingCharacters(in: .whitespaces)
    }
}

extension BuildSettingResolver {
    func resolveFileCompilerFlags(
        for fileURL: URL
    ) -> [String]? {
        // === Old: PBXBuildFile.settings.COMPILER_FLAGS ===
        let oldFlags = resolveOldFileFlags(for: fileURL, sourceRoot: sourceRoot)
        if !oldFlags.isEmpty {
            return oldFlags
        }

        // === New: PBXFileSystemSynchronizedRootGroup → exceptions →
        // BuildFileExceptionSet ===
        // === Xcode15+: PBXFileSystemSynchronizedBuildFileExceptionSet ===
        return resolveNewFileFlags(
            for: fileURL,
            target: xcodeProjTarget,
            sourceRoot: sourceRoot
        )
    }

    private func resolveOldFileFlags(
        for fileURL: URL,
        sourceRoot: Path
    ) -> [String] {
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

    private func resolveNewFileFlags(
        for fileURL: URL,
        target: PBXNativeTarget,
        sourceRoot: Path
    ) -> [String] {
        var flags: [String] = []
        for rootGroup in target.fileSystemSynchronizedGroups ?? [] {
            for exception in rootGroup.exceptions ?? [] {
                guard
                    let exceptionSet =
                    exception as? PBXFileSystemSynchronizedBuildFileExceptionSet,
                    let groupPath = rootGroup.path
                else { continue }

                for (relativePath, compilerFlags) in exceptionSet
                    .additionalCompilerFlagsByRelativePath ?? [:] {
                    let absPath = sourceRoot + groupPath + relativePath
                    if absPath.url == fileURL {
                        flags += compilerFlags.split(separator: " ")
                            .map { String($0) }
                    }
                }
            }
        }
        return flags
    }
}
