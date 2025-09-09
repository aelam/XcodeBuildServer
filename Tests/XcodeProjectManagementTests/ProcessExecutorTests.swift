import Support
import Testing
import XcodeProjectManagement

struct ProcessExecutorTests {
    @Test
    func regularExecution() async throws {
        let processExecutor = ProcessExecutor()
        let result = try await processExecutor.execute(
            executable: "/bin/ls",
            arguments: ["-l"],
            workingDirectory: nil,
            environment: [:],
            timeout: 5.0
        )
        #expect(result.exitCode == 0)
    }

    @Test("ProcessExecutor timeout test", .disabled("Skipping timeout test in CI"))
    func timeoutError() async throws {
        let processExecutor = ProcessExecutor()
        let error = try await #require(throws: ProcessExecutorError.self) {
            try await processExecutor.execute(
                executable: "/usr/bin/yes",
                arguments: [],
                workingDirectory: nil,
                environment: [:],
                timeout: 0.1
            )
        }
        #expect(error.isTimeout)
    }
}
