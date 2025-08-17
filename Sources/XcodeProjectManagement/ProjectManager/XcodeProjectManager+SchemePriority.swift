import Logger

extension XcodeProjectManager {
    func matchTarget(for scheme: XcodeScheme, targets: [XcodeTarget]) -> XcodeTarget? {
        guard
            let projectURL = scheme.primaryBuildTargetProjectURL,
            let productName = scheme.primaryProductName ?? scheme.primaryTarget
        else {
            return nil
        }
        return targets.first {
            $0.projectURL == projectURL && $0.productNameWithExtension == productName
        }
    }

    func loadSchemsWithPriority(
        schemes: [XcodeScheme],
        targets: [XcodeTarget]
    ) -> [XcodeScheme] {
        let schemesWithPriority: [(scheme: XcodeScheme, priority: Double)] =
            schemes.compactMap { scheme in
                if let target = matchTarget(for: scheme, targets: targets) {
                    logger.debug("Scheme '\(scheme.name)' 匹配到 target '\(target.name)'，priority=\(target.priority)")
                    return (scheme: scheme, priority: target.priority)
                } else {
                    return (scheme: scheme, priority: 0) // 没有匹配到 target，priority=0
                }
            }

        return schemesWithPriority
            .sorted { $0.priority > $1.priority }
            .map(\.scheme)
    }
}
