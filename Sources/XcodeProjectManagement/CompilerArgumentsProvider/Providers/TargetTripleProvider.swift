import Foundation

struct TargetTripleProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard
            let targetTriple = context.buildSettings["TARGET_TRIPLE"]
        else {
            return []
        }
        return ["-target", targetTriple]
    }
}
