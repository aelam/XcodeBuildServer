//
//  CrossPlatformLock.swift
//
//  Copyright © 2024 Wang Lun.
//

import Foundation
#if canImport(os) && os(macOS)
import os

/// A cross-platform thread-safe lock wrapper
public final class CrossPlatformLock<State: Sendable>: @unchecked Sendable {
    private let lock: OSAllocatedUnfairLock<State>

    public init(initialState: State) {
        self.lock = OSAllocatedUnfairLock(initialState: initialState)
    }

    public func withLock<T: Sendable>(_ operation: @Sendable (inout State) -> T) -> T {
        lock.withLock(operation)
    }
}

#else

/// A cross-platform thread-safe lock wrapper
public final class CrossPlatformLock<State: Sendable>: @unchecked Sendable {
    private let nsLock = NSLock()
    private var state: State

    public init(initialState: State) {
        self.state = initialState
    }

    public func withLock<T: Sendable>(_ operation: @Sendable (inout State) -> T) -> T {
        nsLock.lock()
        defer { nsLock.unlock() }
        return operation(&state)
    }
}

#endif
