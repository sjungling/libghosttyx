import AppKit
import libghostty

/// Builder for `ghostty_surface_config_s`.
///
/// Provides a convenient way to construct surface configuration before
/// creating a new ghostty surface.
@MainActor
public struct GhosttySurfaceConfig {
    /// The NSView that will host the terminal surface.
    public var nsView: NSView?

    /// Opaque userdata pointer passed back in surface callbacks.
    public var userdata: UnsafeMutableRawPointer?

    /// Display scale factor (e.g. 2.0 for Retina).
    public var scaleFactor: Double = 2.0

    /// Initial font size. 0 means use default from config.
    public var fontSize: Float = 0

    /// Working directory for the shell. nil means inherit.
    public var workingDirectory: String?

    /// Command to run. nil means use default shell.
    public var command: String?

    /// Additional environment variables.
    public var environmentVariables: [(key: String, value: String)] = []

    /// Context for this surface (window, tab, or split).
    public var context: ghostty_surface_context_e = GHOSTTY_SURFACE_CONTEXT_WINDOW

    public init() {}

    /// Builds the C struct, calling the provided closure with a pointer to it.
    ///
    /// The closure pattern is used because the struct contains pointers to
    /// temporary C strings that must remain valid during the call.
    func withCConfig<T>(_ body: (inout ghostty_surface_config_s) throws -> T) rethrows -> T {
        var config = ghostty_surface_config_new()
        config.platform_tag = GHOSTTY_PLATFORM_MACOS

        if let view = nsView {
            config.platform = ghostty_platform_u(
                macos: ghostty_platform_macos_s(
                    nsview: Unmanaged.passUnretained(view).toOpaque()
                )
            )
        }

        config.userdata = userdata
        config.scale_factor = scaleFactor
        config.font_size = fontSize
        config.context = context

        // Use withCString for string fields to keep pointers alive
        return try withOptionalCString(workingDirectory) { wdPtr in
            config.working_directory = wdPtr
            return try withOptionalCString(command) { cmdPtr in
                config.command = cmdPtr
                return try withEnvVars(environmentVariables) { envPtr, envCount in
                    config.env_vars = envPtr
                    config.env_var_count = envCount
                    return try body(&config)
                }
            }
        }
    }
}

// MARK: - Helpers

private func withOptionalCString<T>(
    _ string: String?,
    _ body: (UnsafePointer<CChar>?) throws -> T
) rethrows -> T {
    if let string = string {
        return try string.withCString { try body($0) }
    } else {
        return try body(nil)
    }
}

private func withEnvVars<T>(
    _ vars: [(key: String, value: String)],
    _ body: (UnsafeMutablePointer<ghostty_env_var_s>?, Int) throws -> T
) rethrows -> T {
    guard !vars.isEmpty else {
        return try body(nil, 0)
    }

    // We need the C strings to stay alive, so we create them as arrays
    let cKeys = vars.map { strdup($0.key) }
    let cValues = vars.map { strdup($0.value) }

    defer {
        cKeys.forEach { free($0) }
        cValues.forEach { free($0) }
    }

    var envVars = zip(cKeys, cValues).map { key, value in
        ghostty_env_var_s(
            key: UnsafePointer(key!),
            value: UnsafePointer(value!)
        )
    }

    return try envVars.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress, buffer.count)
    }
}
