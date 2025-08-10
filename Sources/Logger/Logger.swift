//
//  Logger.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
@preconcurrency import OSLog
import SwiftyBeaver

nonisolated(unsafe) let privacy: OSLogPrivacy = .public

public final class SwiftyBeaverLogger: @unchecked Sendable {
    private let log = SwiftyBeaver.self

    public init() {
        setupLogger()
    }

    private func setupLogger() {
        let console = ConsoleDestination()
        console.format = "$DHH:mm:ss$d $L $N.$F:$l $C$M$c"
        console.levelColor.verbose = "🔍 "
        console.levelColor.debug = "🔧 "
        console.levelColor.info = "ℹ️ "
        console.levelColor.warning = "⚠️ "
        console.levelColor.error = "❌ "
        log.addDestination(console)

        let file = FileDestination()
        file.logFileURL = URL(fileURLWithPath: "/tmp/xcode-build-server.log")
        file.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $L $N.$F:$l $M"
        log.addDestination(file)
    }

    public func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        log.info(message, file: file, function: function, line: line, context: context)
    }

    public func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        log.debug(message, file: file, function: function, line: line, context: context)
    }

    public func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        log.error(message, file: file, function: function, line: line, context: context)
    }

    public func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        context: Any? = nil
    ) {
        log.warning(message, file: file, function: function, line: line, context: context)
    }
}

public let logger = SwiftyBeaverLogger()
