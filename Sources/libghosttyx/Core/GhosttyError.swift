import Foundation

/// Errors that can occur when interacting with libghostty.
public enum GhosttyError: Error, LocalizedError {
    /// Failed to initialize the ghostty runtime via `ghostty_init`.
    case initializationFailed

    /// Failed to create a new ghostty app instance.
    case appCreationFailed

    /// Failed to create a new ghostty config.
    case configCreationFailed

    /// Failed to create a new ghostty surface.
    case surfaceCreationFailed

    /// The engine has already been initialized.
    case alreadyInitialized

    /// The engine has not been initialized yet.
    case notInitialized

    /// A config key was not found.
    case configKeyNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize the ghostty runtime."
        case .appCreationFailed:
            return "Failed to create the ghostty app instance."
        case .configCreationFailed:
            return "Failed to create a ghostty config."
        case .surfaceCreationFailed:
            return "Failed to create a ghostty surface."
        case .alreadyInitialized:
            return "The ghostty engine has already been initialized."
        case .notInitialized:
            return "The ghostty engine has not been initialized. Call GhosttyEngine.shared.initialize() first."
        case .configKeyNotFound(let key):
            return "Config key not found: \(key)"
        }
    }
}
