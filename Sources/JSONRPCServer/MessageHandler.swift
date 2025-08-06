//
//  MessageHandler.swift
//
//  Copyright © 2024 Wang Lun.
//

/// An abstract message handler, such as a language server or client.
public protocol MessageHandler: AnyObject, Sendable {}

/// A message handler that provides controlled access to build server context.
/// This protocol allows request handlers to access context in a type-safe manner
/// without requiring direct coupling to specific handler implementations.
public protocol ContextualMessageHandler: MessageHandler {
    /// The type of context this handler provides access to.
    associatedtype Context: Sendable

    /// Executes an operation with access to the build server context.
    /// This method provides scoped access to the context, ensuring proper isolation
    /// and error handling while maintaining actor safety.
    ///
    /// - Parameter operation: An async closure that receives the build server context
    /// - Returns: The result of the operation
    /// - Throws: Any error thrown by the operation or context access failures
    func withContext<T>(_ operation: @escaping @Sendable (Context) async throws -> T) async rethrows -> T
}
