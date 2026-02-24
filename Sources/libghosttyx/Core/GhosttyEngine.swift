import AppKit
import libghostty

/// Singleton that manages the `ghostty_app_t` instance.
///
/// There can only be one ghostty app per process (matching upstream design).
/// Multiple `TerminalView` instances create multiple surfaces under this single app.
///
/// ## Usage
/// ```swift
/// // At app startup:
/// try GhosttyEngine.shared.initialize(config: TerminalConfiguration(
///     fontFamily: "JetBrains Mono", fontSize: 14
/// ))
///
/// // The engine is now ready for TerminalView instances to create surfaces.
/// ```
@MainActor
public final class GhosttyEngine {
    /// The shared engine instance.
    public static let shared = GhosttyEngine()

    /// The raw ghostty app handle.
    private(set) var app: ghostty_app_t?

    /// The config used to create the app.
    private(set) var config: GhosttyConfig?

    /// Whether the engine has been initialized.
    public var isInitialized: Bool { app != nil }

    private init() {}

    /// Initializes the engine with the given terminal configuration.
    ///
    /// This must be called once before creating any `TerminalView` instances.
    /// Typically called in `applicationDidFinishLaunching` or in a SwiftUI `App.init`.
    ///
    /// - Parameter config: Terminal configuration. Uses defaults if nil.
    /// - Throws: `GhosttyError` if initialization fails.
    public func initialize(config termConfig: TerminalConfiguration = .init()) throws {
        guard app == nil else { throw GhosttyError.alreadyInitialized }

        // Initialize the ghostty runtime
        let initResult = ghostty_init(0, nil)
        guard initResult == 0 else {
            throw GhosttyError.initializationFailed
        }

        // Create and configure the config
        let cfg = try GhosttyConfig()

        // Load custom config file if specified
        if let customPath = termConfig.customConfigPath {
            cfg.loadFile(customPath)
        }

        // Load defaults and CLI args
        cfg.loadDefaultFiles()
        cfg.loadCLIArgs()
        cfg.loadRecursiveFiles()

        // Apply high-level configuration overrides
        applyConfiguration(termConfig, to: cfg)

        // Finalize config (populates defaults)
        cfg.finalize()

        self.config = cfg

        // Build runtime config with callback trampolines
        var runtimeConfig = GhosttyCallbackBridge.runtimeConfig(for: self)

        // Create the app
        guard let appInstance = ghostty_app_new(&runtimeConfig, cfg.rawConfig) else {
            throw GhosttyError.appCreationFailed
        }

        self.app = appInstance

        // Set initial focus based on NSApp state
        ghostty_app_set_focus(appInstance, NSApp?.isActive ?? false)

        // Detect initial color scheme
        let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ghostty_app_set_color_scheme(appInstance, isDark ? GHOSTTY_COLOR_SCHEME_DARK : GHOSTTY_COLOR_SCHEME_LIGHT)
    }

    /// Processes pending events. Called from the wakeup callback.
    func tick() {
        guard let app = app else { return }
        ghostty_app_tick(app)
    }

    /// Notifies the engine of app focus changes.
    public func setFocus(_ focused: Bool) {
        guard let app = app else { return }
        ghostty_app_set_focus(app, focused)
    }

    /// Notifies the engine of color scheme changes.
    public func setColorScheme(_ scheme: ghostty_color_scheme_e) {
        guard let app = app else { return }
        ghostty_app_set_color_scheme(app, scheme)
    }

    /// Notifies the engine that the keyboard layout has changed.
    public func keyboardChanged() {
        guard let app = app else { return }
        ghostty_app_keyboard_changed(app)
    }

    /// Creates a new surface for the given terminal view.
    func createSurface(
        for view: TerminalView,
        config surfaceConfig: GhosttySurfaceConfig
    ) throws -> GhosttySurface {
        guard let app = app else { throw GhosttyError.notInitialized }

        var cfg = surfaceConfig
        cfg.nsView = view
        cfg.userdata = Unmanaged.passUnretained(view).toOpaque()

        return try cfg.withCConfig { cConfig in
            try GhosttySurface(app: app, config: &cConfig)
        }
    }

    // MARK: - Private

    /// Applies high-level `TerminalConfiguration` values to the ghostty config.
    ///
    /// Note: ghostty_config doesn't have a "set" API — config values come from
    /// files and CLI args. To apply programmatic config, we'd need to create a
    /// temporary config file or set environment variables. For now, we support
    /// customConfigPath and rely on file-based config.
    ///
    /// Font size is applied per-surface via `ghostty_surface_config_s.font_size`.
    private func applyConfiguration(_ termConfig: TerminalConfiguration, to cfg: GhosttyConfig) {
        // The ghostty config API is read-only from Swift.
        // Config values must be set via config files (customConfigPath) or CLI args.
        // Font size can be overridden per-surface.
    }
}
