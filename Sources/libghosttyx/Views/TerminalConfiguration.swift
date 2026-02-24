import Foundation

/// High-level configuration for a terminal session.
///
/// Maps to ghostty config keys. Values set here override the ghostty config file.
/// For full customization, use `customConfigPath` to point to a ghostty config file.
public struct TerminalConfiguration: Sendable {
    /// Font family name (e.g. "JetBrains Mono", "SF Mono").
    public var fontFamily: String?

    /// Font size in points. 0 means use ghostty's default.
    public var fontSize: Float

    /// Path to a ghostty config file for full customization.
    public var customConfigPath: String?

    /// Working directory for the shell. nil means inherit.
    public var workingDirectory: String?

    /// Command to run instead of the default shell. nil means use $SHELL.
    public var command: String?

    /// Additional environment variables to set.
    public var environmentVariables: [(key: String, value: String)]

    public init(
        fontFamily: String? = nil,
        fontSize: Float = 0,
        customConfigPath: String? = nil,
        workingDirectory: String? = nil,
        command: String? = nil,
        environmentVariables: [(key: String, value: String)] = []
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.customConfigPath = customConfigPath
        self.workingDirectory = workingDirectory
        self.command = command
        self.environmentVariables = environmentVariables
    }
}
