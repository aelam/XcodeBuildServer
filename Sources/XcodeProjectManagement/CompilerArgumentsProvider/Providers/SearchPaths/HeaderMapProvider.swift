import Foundation

struct HeaderMapProvider: CompileArgProvider, Sendable {
    // MARK: - Swift

    // "-Xcc",
    // "-I/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/Hello.build/Debug-iphoneos/Hello.build/swift-overrides.hmap",
    // "-Xcc",
    // "-iquote",
    // "-Xcc",
    // "/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/Hello.build/Debug-iphoneos/Hello.build/Hello-generated-files.hmap",
    // "-Xcc",
    // "-I/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/Hello.build/Debug-iphoneos/Hello.build/Hello-own-target-headers.hmap",
    // "-Xcc",
    // "-I/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/Hello.build/Debug-iphoneos/Hello.build/Hello-all-target-headers.hmap",
    // "-Xcc",
    // "-iquote",
    // "-Xcc",
    // "/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/Hello.build/Debug-iphoneos/Hello.build/Hello-project-headers.hmap",

    // MARK: - clang

    // "-iquote",
    // "/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/World.build/Debug-iphoneos/World1.build/World1-generated-files.hmap",
    // "-I/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/World.build/Debug-iphoneos/World1.build/World1-own-target-headers.hmap",
    // "-I/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/World.build/Debug-iphoneos/World1.build/World1-all-target-headers.hmap",
    // "-iquote",
    // "/Users/wang.lun/Library/Developer/Xcode/DerivedData/Hello-eioqmlribgyczeeyslecouumkyay/Build/Intermediates.noindex/World.build/Debug-iphoneos/World1.build/World1-project-headers.hmap",

    func arguments(for context: ArgContext) -> [String] {
        guard
            let targetName = context.buildSettings[BuildSettingKey.targetName.rawValue],
            let configurationTempDir = context.buildSettings[BuildSettingKey.configurationTempDir.rawValue]
        else {
            return []
        }
        let base: [[String]] = [
            ["-iquote", "\(configurationTempDir)/\(targetName)-generated-files.hmap"],
            ["-I\(configurationTempDir)/\(targetName)-own-target-headers.hmap"],
            ["-I\(configurationTempDir)/\(targetName)-all-target-headers.hmap"],
            ["-iquote", "\(configurationTempDir)/\(targetName)-project-headers.hmap"]
        ]

        let swiftOnly: [[String]] = [
            ["-iquote", "-I\(configurationTempDir)/swift-overrides.hmap"]
        ]

        switch context.compiler {
        case .swift:
            let args = base.flatMap(\.self) + swiftOnly.flatMap(\.self)
            // 每个参数都加上 -Xcc
            return args.flatMap { ["-Xcc", $0] }
        case .clang:
            return base.flatMap(\.self)
        }
    }
}
