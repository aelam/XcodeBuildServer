//
//  main.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import XcodeBuildServer

func run() {
    let server = JSONRPCServer(
        transport: StdioJSONRPCServerTransport(),
        messageRegistry: bspRegistry,
        messageHandler: XcodeBSPMessageHandler()
    )

    Task { @MainActor in
        await server.listen()
    }

    Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
        killSelfIfParentIsNull()
    }

    // Run the main loop to keep the program running and listening for changes
    RunLoop.main.run()
}

func killSelfIfParentIsNull() {
    let parentProcessID = getppid()

    // If parent process is 1, it's typically the init process, indicating the parent is null
    if parentProcessID == 1 {
        print("Parent process is null, killing self...")
        exit(0) // Exit the process cleanly
    }
}

run()
