//
//  Logger.swift
//
//  Copyright © 2024 Wang Lun.
//

@preconcurrency import OSLog

nonisolated(unsafe) let privacy: OSLogPrivacy = .public
let logger = Logger(
    subsystem: "XcodeBuildServer",
    category: "main"
)
