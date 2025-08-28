import Foundation
import XcodeProj

/// 通用 Xcode Build Setting 解析器。支持递归查找、$(inherited) 合并、自定义默认值。
public class BuildSettingResolver {
    public let project: PBXProject
    public let target: PBXTarget
    public let configuration: XCBuildConfiguration?
    public var customDefaults: [String: String]

    public init(
        project: PBXProject,
        target: PBXTarget,
        configuration: XCBuildConfiguration?,
        customDefaults: [String: String] = [:]
    ) {
        self.project = project
        self.target = target
        self.configuration = configuration
        self.customDefaults = customDefaults
    }

    /// 主入口：解析任意 build setting key 的最终值（$(inherited) 递归合并）
    public func resolve(forKey key: String) -> String? {
        // 1. 配置级别
        let configVal = configuration?.buildSettings[key] as? String
        // 2. Target级别
        let targetVal = getBuildSettingsFromConfigList(target.buildConfigurationList, key: key)
        // 3. Project级别
        let projectVal = getBuildSettingsFromConfigList(project.buildConfigurationList, key: key)
        // 4. 自定义默认值
        let customDefault = customDefaults[key]
        // 5. 全局默认值
        let globalDefault = BuildSettingResolver.defaultFor(key: key)

        // 递归合并 inherit
        return expandInherited(
            configVal,
            parent: expandInherited(
                targetVal,
                parent: expandInherited(projectVal, parent: customDefault ?? globalDefault)
            )
        )
    }

    /// 获取 configList 的 buildSetting（优先第一个配置）
    private func getBuildSettingsFromConfigList(_ configList: XCConfigurationList?, key: String) -> String? {
        guard let configs = configList?.buildConfigurations else { return nil }
        for config in configs {
            if let v = config.buildSettings[key] as? String, !v.isEmpty { return v }
        }
        return nil
    }

    /// 递归处理 $(inherited)，层层合并
    private func expandInherited(_ value: String?, parent: String?) -> String? {
        guard let value, !value.isEmpty else { return parent }
        if value.contains("$(inherited)") {
            let replaced = value.replacingOccurrences(of: "$(inherited)", with: parent ?? "")
            return replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // 多个值用空格分隔时也可以合并
            if let parent, !parent.isEmpty, !value.contains(parent) {
                return (parent + " " + value).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return value
        }
    }

    /// 可扩展的全局默认值
    public static func defaultFor(key: String) -> String? {
        switch key {
        case "SDKROOT": "iphonesimulator"
        case "ARCHS": "arm64"
        case "PLATFORM_NAME": "iphonesimulator"
        case "IPHONEOS_DEPLOYMENT_TARGET": "18.0"
        case "SWIFT_VERSION": "5.0"
        case "CODE_SIGN_IDENTITY": ""
        default: nil
        }
    }
}
