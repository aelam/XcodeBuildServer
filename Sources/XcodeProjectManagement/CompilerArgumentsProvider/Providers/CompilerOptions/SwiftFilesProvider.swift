import Foundation

struct SwiftFilesProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard context.compiler == .swift else { return [] }
        // Provide the necessary arguments for Swift files
        let sourceItems = context.sourceItems

        guard !sourceItems.isEmpty else {
            return []
        }

        // Generate Swift File List
        var fileList: [String] = []
        for item in sourceItems {
            if item.itemKind != .file, item.path.pathExtension == "swift" {
                fileList.append(item.path.path)
            } else {
                let filePaths = (try? FileManager.default.contentsOfDirectory(
                    at: item.path,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )) ?? []
                filePaths.filter { url in
                    url.pathExtension == "swift"
                }.forEach { file in
                    fileList.append(file.path)
                }
            }
        }

        return fileList
    }
}
