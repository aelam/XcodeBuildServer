public enum BSPStatusCode: Int, Codable, Sendable {
    /** Execution was successful. */
    case ok = 1

    /** Execution failed. */
    case error = 2

    /** Execution was cancelled. */
    case cancelled = 3
}
