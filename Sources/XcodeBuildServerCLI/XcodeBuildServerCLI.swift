//
//  XcodeBuildServerCLI.swift
//
//  Copyright © 2024 Wang Lun.

import Foundation
import JSONRPCServer
import SwiftyBeaver
import XcodeBuildServer

@main
struct XcodeBuildServerCLI {
    static func main() async {
        // Initialize SwiftyBeaver logging
        let environment = ProcessInfo.processInfo.environment["BSP_ENVIRONMENT"] ?? "development"

        // Log startup message
        XcodeBuildServer.logger
            .info(
                "XcodeBuildServer started successfully - PID: \(ProcessInfo.processInfo.processIdentifier) " +
                    "- Environment: \(environment)"
            )

        let arguments = CommandLine.arguments

        // Parse command line arguments - only for help
        if arguments.count > 1 {
            let firstArg = arguments[1]
            if firstArg == "--help" || firstArg == "-h" {
                printUsage()
                exit(0)
            }
        }

        // Start BSP server - project discovery happens on build/initialize request
        let messageHandler = XcodeBSPMessageHandler()

        // Check for debug mode from environment variable
        let isDebugMode = ProcessInfo.processInfo.environment["BSP_DEBUG"] != nil ||
            arguments.contains("--debug")

        if isDebugMode {
            let debugMsg = "🔧 BSP Debug Mode Enabled - PID: \(ProcessInfo.processInfo.processIdentifier)"
            logger.debug(debugMsg)
        }

        let transport = StdioJSONRPCServerTransport()
        let server = JSONRPCServer(
            transport: transport,
            messageRegistry: bspRegistry,
            messageHandler: messageHandler
        )

        // Monitor parent process at a reasonable interval using Task
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                killSelfIfParentIsNull()
            }
        }

        do {
            try await server.listen()
        } catch {
            // Log error
            let errorMsg = "Server failed to start: \(error)"
            logger.error(errorMsg)
            exit(1)
        }
    }

    private static func printUsage() {
        print("Usage: XcodeBuildServerCLI")
        print("")
        print("Description:")
        print("  Starts an Xcode Build Server Protocol (BSP) server that communicates")
        print("  via JSON-RPC over stdin/stdout. The server waits for BSP requests")
        print("  from compatible IDEs or tools.")
        print("")
        print("  Project discovery happens when the client sends a 'build/initialize'")
        print("  request with the workspace root URI.")
        print("")
        print("Options:")
        print("  -h, --help      Show this help message and exit")
        print("")
        print("BSP Protocol:")
        print("  The server implements the Build Server Protocol specification.")
        print("  See: https://build-server-protocol.github.io/")
        print("")
        print("Examples:")
        print("  XcodeBuildServerCLI                    # Start BSP server")
        print("  echo '{\"id\":1,\"method\":\"build/initialize\"...}' | XcodeBuildServerCLI")
    }

    private static func killSelfIfParentIsNull() {
        let parentProcessID = getppid()

        // Check if parent process is init (PID 1) or doesn't exist
        if parentProcessID == 1 {
            let msg = "🔴 Parent process became init (PID 1), terminating..."
            logger.warning(msg)
            exit(0)
        }

        // Additional check: verify parent process still exists and is not a zombie
        let result = kill(parentProcessID, 0) // Signal 0 just checks if process exists
        if result == -1 {
            if errno == ESRCH {
                let msg = "🔴 Parent process (PID \(parentProcessID)) no longer exists (ESRCH), " + "terminating..."
                logger.warning(msg)
                exit(0)
            } else if errno == EPERM {
                // Parent exists, but we don't have permission; do not exit
                let msg = "🟡 Parent process (PID \(parentProcessID)) exists " +
                    "but permission denied (EPERM), not terminating."
                logger.debug(msg)
            }
        } else {
            let msg = "🟠 kill() failed for parent process (PID \(parentProcessID)), " +
                " errno: \(errno), not terminating."
            logger.debug(msg)
        }
    }
}
