//
//  main.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeBuildServer

@main
struct XcodeBuildServerCLI {
    static func main() async {
        let server = JSONRPCServer(
            transport: StdioJSONRPCServerTransport(),
            messageRegistry: bspRegistry,
            messageHandler: XcodeBSPMessageHandler()
        )

        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            killSelfIfParentIsNull()
        }

        await server.listen()
    }

    private static func killSelfIfParentIsNull() {
        let parentProcessID = getppid()
        // If parent process is 1, it's typically the init process, indicating the parent is null
        if parentProcessID == 1 {
            print("Parent process is null, killing self...")
            exit(0) // Exit the process cleanly
        }
    }
}
