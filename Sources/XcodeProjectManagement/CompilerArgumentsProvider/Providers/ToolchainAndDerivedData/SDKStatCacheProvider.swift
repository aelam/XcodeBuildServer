import Foundation

struct SDKStatCacheProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard
            let buildVersion = context.xcodeInstallation?.buildVersion,
            let sdkPath = context.buildSettings["SDKROOT_PATH"],
            let sdkVersion = context.buildSettings["SDK_VERSION"],
            let platformName = context.buildSettings["PLATFORM_NAME"]
        else {
            return []
        }

        let sdkStatCachesDir = context.derivedDataPath
            .deletingLastPathComponent()
            .appendingPathComponent("SDKStatCaches.noindex")

        let sdkHash = sdkPath.md5()
        let pathComponent = "\(platformName)\(sdkVersion)-\(buildVersion)-\(sdkHash).sdkstatcache"
        let sdkStateCachePath = sdkStatCachesDir.appendingPathComponent(pathComponent).path

        if context.compiler == .clang {
            return [
                "-ivfsstatcache",
                sdkStateCachePath
            ]
        } else {
            return [
                "-Xcc", "-ivfsstatcache",
                "-Xcc", sdkStateCachePath
            ]
        }
    }
}
