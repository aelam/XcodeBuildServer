
import XcodeBuildServer
import Foundation

let server = JSONRPCServer(
    transport: StdioJSONRPCServerTransport(),
    messageRegistry: bspRegistry,
    messageHandler: XcodeBSPMessageHandler()
)

Task { @MainActor in
    await server.listen()
}
RunLoop.main.run()
