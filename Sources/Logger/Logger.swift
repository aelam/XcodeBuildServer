//
//  Logger.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
import SwiftyBeaver

public final class SwiftyBeaverLogger: @unchecked Sendable {
    private let log = SwiftyBeaver.self

    public init() {
        setupLogger()
    }

    private func setupLogger() {
        // 重要：不使用ConsoleDestination，因为它会输出到stdout
        // 这会与JSON-RPC消息混合，导致client解析失败
        // let console = ConsoleDestination()
        // log.addDestination(console)

        let file = FileDestination()
        file.logFileURL = URL(fileURLWithPath: "/tmp/sourcekit-bsp.log")
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
