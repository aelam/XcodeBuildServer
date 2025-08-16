import Foundation
import PathKit
import Testing
import XcodeProj // @tuist ~> 8.8.0

struct XcodeProjTests {
    @Test
    func workspaceInitialization() throws {
        let path = "/Users/wang.lun/Work/line-stickers-ios/UserStickers.xcworkspace"
        let projectPath = Path(path)
        let workspace = try XCWorkspace(path: projectPath)
        print(workspace)
        print(workspace.data.children)
        for child in workspace.data.children {
            print("Child: \(child)")
        }
    }
}
