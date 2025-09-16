import Foundation
import Logger
import Support

// MARK: - Process Output Handler Protocol

public protocol ProcessOutputHandler: Sendable {
    func handleProcess(output: FileHandle, error: FileHandle) async
    func handleCompletion(_ exitCode: Int32) async
}

// MARK: - Default Output Handler

struct DefaultOutputHandler: ProcessOutputHandler {
    func handleProcess(output: FileHandle, error: FileHandle) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await StreamingFileHandleReader.streamPipe(output) { line in
                    logger.info("Build output: \(line)")
                }
            }

            group.addTask {
                await StreamingFileHandleReader.streamPipe(error) { line in
                    logger.error("Build error: \(line)")
                }
            }
        }
    }

    func handleCompletion(_ exitCode: Int32) async {
        logger.info("Process completed with exit code: \(exitCode)")
    }
}
