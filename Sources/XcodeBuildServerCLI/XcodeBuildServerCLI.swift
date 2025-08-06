//
//  XcodeBuildServerCLI.swift
//
//  Copyright © 2024 Wang Lun.

import Foundation
import JSONRPCServer
import XcodeBuildServer

@main
struct XcodeBuildServerCLI {
    static func main() async {
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
            print("🔧 BSP Debug Mode Enabled")
            print("📝 Logging JSON-RPC communication to stderr")
            print("📡 PID: \(ProcessInfo.processInfo.processIdentifier)")
        }

        let transport = StdioJSONRPCServerTransport()
        let server = JSONRPCServer(
            transport: transport,
            messageRegistry: bspRegistry,
            messageHandler: messageHandler
        )

        // Monitor parent process at a reasonable interval
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            killSelfIfParentIsNull()
        }

        do {
            try await server.listen()
        } catch {
            print("Server failed to start: \(error)")
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
            if ProcessInfo.processInfo.environment["BSP_DEBUG"] != nil {
                fputs("🔴 Parent process became init (PID 1), terminating...\n", stderr)
            }
            exit(0)
        }
        
        // Additional check: verify parent process still exists and is not a zombie
        let result = kill(parentProcessID, 0) // Signal 0 just checks if process exists
        if result != 0 {
            if ProcessInfo.processInfo.environment["BSP_DEBUG"] != nil {
                fputs("🔴 Parent process (PID \(parentProcessID)) no longer exists, terminating...\n", stderr)
            }
            exit(0)
        }
        
        // Additional check: verify parent process still exists and is not a zombie
        let result = kill(parentProcessID, 0) // Signal 0 just checks if process exists
        if result == -1 {
            if errno == ESRCH {
                if ProcessInfo.processInfo.environment["BSP_DEBUG"] != nil {
                    fputs("🔴 Parent process (PID \(parentProcessID)) no longer exists (ESRCH), terminating...\n", stderr)
                }
                exit(0)
            } else if errno == EPERM {
                // Parent exists, but we don't have permission; do not exit
                if ProcessInfo.processInfo.environment["BSP_DEBUG"] != nil {
                    fputs("🟡 Parent process (PID \(parentProcessID)) exists but permission denied (EPERM), not terminating.\n", stderr)
                }
            } else {
                if ProcessInfo.processInfo.environment["BSP_DEBUG"] != nil {
                    fputs("🟠 kill() failed for parent process (PID \(parentProcessID)), errno: \(errno), not terminating.\n", stderr)
                }
            }
        }
    }
}
