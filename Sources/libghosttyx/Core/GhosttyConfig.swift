import Foundation
import libghostty

/// Swift wrapper around `ghostty_config_t`.
///
/// Manages the lifecycle of a ghostty config object and provides typed accessors
/// for config values.
@MainActor
public final class GhosttyConfig {
    private(set) var rawConfig: ghostty_config_t?

    /// Creates a new empty config.
    public init() throws {
        guard let cfg = ghostty_config_new() else {
            throw GhosttyError.configCreationFailed
        }
        rawConfig = cfg
    }

    /// Creates a wrapper around an existing config pointer. Does NOT take ownership.
    init(borrowing config: ghostty_config_t) {
        rawConfig = config
    }

    /// Creates a wrapper by cloning an existing config.
    init(cloning config: ghostty_config_t) {
        rawConfig = ghostty_config_clone(config)
    }

    deinit {
        if let cfg = rawConfig {
            ghostty_config_free(cfg)
        }
    }

    /// Loads the default config files (~/.config/ghostty/config, etc.).
    public func loadDefaultFiles() {
        guard let cfg = rawConfig else { return }
        ghostty_config_load_default_files(cfg)
    }

    /// Loads a specific config file.
    public func loadFile(_ path: String) {
        guard let cfg = rawConfig else { return }
        path.withCString { cPath in
            ghostty_config_load_file(cfg, cPath)
        }
    }

    /// Loads config from process CLI arguments.
    public func loadCLIArgs() {
        guard let cfg = rawConfig else { return }
        ghostty_config_load_cli_args(cfg)
    }

    /// Loads recursive config file directives.
    public func loadRecursiveFiles() {
        guard let cfg = rawConfig else { return }
        ghostty_config_load_recursive_files(cfg)
    }

    /// Finalizes the config, applying defaults. Must be called before reading values.
    public func finalize() {
        guard let cfg = rawConfig else { return }
        ghostty_config_finalize(cfg)
    }

    /// Number of config diagnostics (errors/warnings from parsing).
    public var diagnosticsCount: UInt32 {
        guard let cfg = rawConfig else { return 0 }
        return ghostty_config_diagnostics_count(cfg)
    }

    // MARK: - Typed Getters

    /// Gets a boolean config value.
    public func getBool(_ key: String) -> Bool? {
        var value = false
        guard get(key, into: &value) else { return nil }
        return value
    }

    /// Gets a string config value.
    public func getString(_ key: String) -> String? {
        var ptr: UnsafePointer<Int8>? = nil
        guard get(key, into: &ptr) else { return nil }
        return ptr.map { String(cString: $0) }
    }

    /// Gets a double config value.
    public func getDouble(_ key: String) -> Double? {
        var value: Double = 0
        guard get(key, into: &value) else { return nil }
        return value
    }

    /// Gets a UInt config value.
    public func getUInt(_ key: String) -> UInt? {
        var value: UInt = 0
        guard get(key, into: &value) else { return nil }
        return value
    }

    /// Gets a color config value as (r, g, b) tuple.
    public func getColor(_ key: String) -> (r: UInt8, g: UInt8, b: UInt8)? {
        var color = ghostty_config_color_s()
        guard get(key, into: &color) else { return nil }
        return (color.r, color.g, color.b)
    }

    // MARK: - Raw Get

    /// Low-level generic config getter. Returns true if the key was found.
    func get<T>(_ key: String, into value: inout T) -> Bool {
        guard let cfg = rawConfig else { return false }
        return key.withCString { cKey in
            ghostty_config_get(cfg, &value, cKey, UInt(key.utf8.count))
        }
    }
}
