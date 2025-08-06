//
//  MessageRegistry.swift
//
//  Copyright © 2024 Wang Lun.
//

/// A registry for JSON-RPC message types that provides compile-time validation.
///
/// This registry ensures:
/// - No duplicate method names within request types
/// - No duplicate method names within notification types
/// - No method name overlap between requests and notifications
///
/// Validation occurs at initialization time with fatal errors for violations.
public final class MessageRegistry: Sendable {
    private let methodToRequest: [String: any RequestType.Type]
    private let methodToNotification: [String: any NotificationType.Type]

    /// Creates a new message registry with compile-time validation.
    ///
    /// - Parameters:
    ///   - requests: Array of request types to register
    ///   - notifications: Array of notification types to register
    /// - Warning: This initializer will call `fatalError()` if duplicate method names are detected
    public init(requests: [any RequestType.Type], notifications: [any NotificationType.Type]) {
        // Validate no duplicate method names in requests
        let requestMethods = requests.map { $0.method() }
        let duplicateRequests = Dictionary(grouping: requestMethods) { $0 }
            .filter { $1.count > 1 }
            .keys

        if !duplicateRequests.isEmpty {
            fatalError("Duplicate request method names found: \(Array(duplicateRequests).joined(separator: ", "))")
        }

        // Validate no duplicate method names in notifications
        let notificationMethods = notifications.map { $0.method() }
        let duplicateNotifications = Dictionary(grouping: notificationMethods) { $0 }
            .filter { $1.count > 1 }
            .keys

        if !duplicateNotifications.isEmpty {
            fatalError(
                "Duplicate notification method names found: \(Array(duplicateNotifications).joined(separator: ", "))"
            )
        }

        // Validate no overlap between request and notification methods
        let methodOverlap = Set(requestMethods).intersection(Set(notificationMethods))
        if !methodOverlap.isEmpty {
            fatalError(
                "Method names overlap between requests and notifications: " +
                    "\(Array(methodOverlap).joined(separator: ", "))"
            )
        }

        methodToRequest = Dictionary(uniqueKeysWithValues: requests.map { ($0.method(), $0) })
        methodToNotification = Dictionary(uniqueKeysWithValues: notifications.map { ($0.method(), $0) })
    }

    /// Returns the request type for the given method name.
    ///
    /// - Parameter method: The JSON-RPC method name to look up
    /// - Returns: The request type if found, nil otherwise
    public func requestType(for method: String) -> (any RequestType.Type)? {
        methodToRequest[method]
    }

    /// Returns the notification type for the given method name.
    ///
    /// - Parameter method: The JSON-RPC method name to look up
    /// - Returns: The notification type if found, nil otherwise
    public func notificationType(for method: String) -> (any NotificationType.Type)? {
        methodToNotification[method]
    }
}
