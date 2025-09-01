//
//  WorkingDirectoryProvider.swift
//  XcodeBuildServer
//
//  Created by wang.lun on 2025/09/01.
//

import Foundation

struct WorkingDirectoryProvider: CompileArgProvider, Sendable {
    func arguments(for context: ArgContext) -> [String] {
        guard let workingDirectory = context.buildSettings["SRCROOT"] else {
            return []
        }
        return ["-working-directory", workingDirectory]
    }
}
