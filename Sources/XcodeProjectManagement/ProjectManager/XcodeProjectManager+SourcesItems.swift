extension XcodeProjectManager {
    public func getSourcesItems(targetIdentifiers: [XcodeTargetIdentifier]) -> [SourcesItem] {
        // Implementation goes here
        guard let xcodeProjectBaseInfo else {
            fatalError("XcodeProjectInfo cannot be resolved before initialize()")
        }

        let sourceFileMap = loadSourceFiles(xcodeProjectBaseInfo: xcodeProjectBaseInfo)

        var sourcesItems: [SourcesItem] = []
        for targetIdentifier in targetIdentifiers {
            let sourceItems = sourceFileMap[targetIdentifier.rawValue] ?? []
            let sourcesItem = SourcesItem(
                target: targetIdentifier,
                sources: sourceItems,
                roots: nil
            )
            sourcesItems.append(sourcesItem)
        }
        return sourcesItems
    }

    private func loadSourceFiles(
        xcodeProjectBaseInfo: XcodeProjectBaseInfo
    ) -> [String: [SourceItem]] {
        let groupedTargets = Dictionary(grouping: xcodeProjectBaseInfo.xcodeTargets, by: \.projectURL)

        return groupedTargets.reduce(into: [String: [SourceItem]]()) { sourceMap, element in
            let (projectURL, targets) = element
            guard let xcodeproj = loadXcodeProjCache(projectURL: projectURL) else {
                return
            }

            let projectSourceMap: [String: [SourceItem]] =
                SourceFileLister.loadSourceFiles(
                    for: xcodeproj,
                    targets: Set(targets.map(\.name))
                )
            sourceMap.merge(projectSourceMap) { $1 }
        }
    }
}
