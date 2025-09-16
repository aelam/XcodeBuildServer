import Testing
@testable import XcodeProjectManagement

struct PathHashTests {
    @Test
    func pathHashing() {
        let projectPath = "/Users/wang.lun/Work/FlashSpace/FlashSpace.xcodeproj"
        let hash = PathHash.hashStringForPath(projectPath)
        print(hash)
    }
}
