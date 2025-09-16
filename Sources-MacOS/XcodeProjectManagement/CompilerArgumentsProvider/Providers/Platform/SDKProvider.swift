import Foundation

struct SDKProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard let sdk = context.buildSettings["SDKROOT_PATH"] else {
            return []
        }
        switch context.compiler {
        case .swift:
            return ["-sdk", sdk]
        case .clang:
            return ["-isysroot", sdk]
        }
    }
}
