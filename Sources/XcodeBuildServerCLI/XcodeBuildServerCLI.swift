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

        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
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

        if parentProcessID == 1 {
            print("Parent process is null, killing self...")
            exit(0)
        }
    }
}
