import Foundation

// "-o",
// "/Users/wang.lun/Work/line-stickers-ios/build/Pods.build/Debug-iphoneos/LCSComponents.build/Objects-normal/arm64/LCSComponents-dummy.o",
// "-index-unit-output-path",
// "/Pods.build/Debug-iphoneos/LCSComponents.build/Objects-normal/arm64/LCSComponents-dummy.o",

struct OutputProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] { [] }
}
