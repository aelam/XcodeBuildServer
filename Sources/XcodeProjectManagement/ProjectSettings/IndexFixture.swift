import Foundation

enum IndexFixture {
    // "assetSymbolIndexPath" :
    // ASIS : "/Users/wang.lun/Work/line-stickers-ios/build/Pods.build/Debug-iphoneos/Alamofire.build/DerivedSources/GeneratedAssetSymbols-Index.plist",
    // TOBE : {derivedDataPath}/Pods.build/{Configuration}-{sdk}/Alamofire.build/DerivedSources/GeneratedAssetSymbols-Index.plist

    enum FixtureKey: String {
        case assetSymbolIndexPath // {target}/{FileName}{assetSymbolIndexPath} :
    }

    struct ProjectBuildSettings: Sendable {
        let projectName: String
        let target: String
        let configuration: String
        let sdk: String
        let derivedDataPath: String

        // CONFIGURATION_BUILD_DIR
        var configurationBuildDir: String {
            "\(derivedDataPath)/\(configuration)-\(sdk)"
        }
    }

    static func fix(
        buildSettingsForIndex: XcodeBuildSettingsForIndex,
        projectBuildSettings: ProjectBuildSettings
    ) -> XcodeBuildSettingsForIndex {
        var fixedSettings = buildSettingsForIndex
        for (targetName, value) in fixedSettings {
            for (filePath, fileBuildSettings) in value {
                var newFileBuildSettingsInfo = fileBuildSettings

                // Fix assetSymbolIndexPath
                if let assetSymbolIndexPath = fileBuildSettings.assetSymbolIndexPath {
                    let fixedPath = fixAssetSymbolIndexPath(
                        path: assetSymbolIndexPath,
                        projectBuildSettings: projectBuildSettings
                    )
                    newFileBuildSettingsInfo.assetSymbolIndexPath = fixedPath
                }

                // Fix clangASTBuiltProductsDir
                if let clangASTBuiltProductsDir = fileBuildSettings.clangASTBuiltProductsDir {
                    let fixedPath = fixClangASTBuiltProductsDir(
                        path: clangASTBuiltProductsDir,
                        projectBuildSettings: projectBuildSettings
                    )
                    newFileBuildSettingsInfo.clangASTBuiltProductsDir = fixedPath
                }

                fixedSettings[targetName]![filePath] = newFileBuildSettingsInfo
            }
        }

        return fixedSettings
    }

    private static func fixAssetSymbolIndexPath(
        path: String,
        projectBuildSettings: ProjectBuildSettings
    ) -> String {
        let derivedDataPath = projectBuildSettings.derivedDataPath
        let configuration = projectBuildSettings.configuration
        let sdk = projectBuildSettings.sdk

        // 查找 .build/ 模式
        guard let buildIndex = path.range(of: ".build/") else { return path }

        // 分割路径
        let beforeBuild = String(path[..<buildIndex.lowerBound])
        let afterBuildSlash = String(path[buildIndex.upperBound...])

        // 查找项目名（最后一个/之后的部分）
        let projectName: String = if let lastSlash = beforeBuild.lastIndex(of: "/") {
            String(beforeBuild[beforeBuild.index(after: lastSlash)...])
        } else {
            beforeBuild
        }

        // 查找配置-SDK部分（第一个/之前）
        guard let nextSlash = afterBuildSlash.firstIndex(of: "/") else { return path }
        let configSdk = String(afterBuildSlash[..<nextSlash])
        let remaining = String(afterBuildSlash[afterBuildSlash.index(after: nextSlash)...])

        // 验证格式
        guard configSdk.contains("-") else { return path }

        return "\(derivedDataPath)/\(projectName).build/\(configuration)-\(sdk)/\(remaining)"
    }

    private static func fixClangASTBuiltProductsDir(
        path: String,
        projectBuildSettings: ProjectBuildSettings
    ) -> String {
        let configurationBuildDir = projectBuildSettings.configurationBuildDir
        if let lastPathComponent = URL(string: path)?.lastPathComponent {
            return configurationBuildDir + lastPathComponent
        }
        return path
    }
}
