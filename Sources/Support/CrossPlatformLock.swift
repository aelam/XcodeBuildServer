//
//  CrossPlatformLock.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
#if canImport(os)
import os
#endif

/// A cross-platform thread-safe lock wrapper
public final class CrossPlatformLock<State: Sendable>: @unchecked Sendable {
    #if canImport(os) && os(macOS)
    private let lock: OSAllocatedUnfairLock<State>
    #else
    private let nsLock = NSLock()
    private var state: State
    #endif

    public init(initialState: State) {
        #if canImport(os) && os(macOS)
        self.lock = OSAllocatedUnfairLock(initialState: initialState)
        #else
        self.state = initialState
        #endif
    }

    public func withLock<T: Sendable>(_ operation: @Sendable (inout State) -> T) -> T {
        #if canImport(os) && os(macOS)
        return lock.withLock(operation)
        #else
        nsLock.lock()
        defer { nsLock.unlock() }
        return operation(&state)
        #endif
    }
}
