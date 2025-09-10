import Testing
@testable import XcodeProjectManagement

struct XcodeDestinationLoaderTests {
    @Test
    func loadDestinations() async throws {
        let destinations = try await XcodeDestinationLoader.loadAllDestinations()

        // 确保至少加载了一些模拟器
        let simulators = destinations.filter { $0.type == .simulator }
        assert(!simulators.isEmpty, "Expected to find some simulator destinations")

        // 确保至少加载了一些真机
        let devices = destinations.filter { $0.type == .device }
        assert(!devices.isEmpty, "Expected to find some device destinations")
    }

    func testFilterDestinations() async throws {
        let destinations = try await XcodeDestinationLoader.loadAllDestinations()

        // 过滤出 iOS 平台的目的地
        let iosDestinations = destinations.filter { $0.platform == .iOS }
        assert(!iosDestinations.isEmpty, "Expected to find some iOS destinations")

        // 过滤出已启动的模拟器
        let bootedSimulators = destinations.filter { $0.type == .simulator && $0.isAvailable }
        assert(!bootedSimulators.isEmpty, "Expected to find some booted simulators")
    }
}
