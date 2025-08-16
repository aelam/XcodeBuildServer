import Testing
import XcodeProjectManagement

struct ProcessExecutorTests {
    @Test
    func example() async throws {
        let processExecutor = ProcessExecutor()
        let result = try await processExecutor.execute(
            executable: "/bin/ls",
            arguments: ["-l"],
            workingDirectory: nil,
            environment: nil,
            timeout: 5.0
        )
        #expect(result.exitCode == 0)
    }

    @Test
    func timeoutError() async throws {
        let processExecutor = ProcessExecutor()
        let error = try await #require(throws: ProcessExecutorError.self) {
            try await processExecutor.execute(
                executable: "/bin/sleep",
                arguments: ["2"],
                workingDirectory: nil,
                environment: nil,
                timeout: 0.5
            )
        }

        guard case let .timeout(duration) = error else {
            Issue.record("Expected timeout error, got \(error)")
            return
        }
        #expect(duration == 0.5)
    }
}
