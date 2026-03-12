import AppKit
import libghosttyx

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, TerminalViewDelegate {
    var window: NSWindow!

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    var terminal: LocalProcessTerminalView!
    var isDarkMode = true

    /// Creates a temporary Ghostty config with light/dark themes so this example
    /// app can visually demonstrate appearance toggling without relying on the
    /// user having a Ghostty config file.
    ///
    /// Downstream apps do NOT need to do this — if the user's Ghostty config
    /// (loaded automatically via `loadDefaultFiles()`) contains a conditional
    /// theme (e.g. `theme = light:X,dark:Y`), color scheme changes will work
    /// out of the box.
    private func createThemeConfig() -> String? {
        let tmpDir = NSTemporaryDirectory() + "BasicTerminalApp"
        let fm = FileManager.default

        // Tell Ghostty where to find our custom themes
        // Ghostty looks for themes in XDG_CONFIG_HOME/ghostty/themes/
        setenv("XDG_CONFIG_HOME", tmpDir, 1)
        let themesDir = tmpDir + "/ghostty/themes"
        try? fm.createDirectory(atPath: themesDir, withIntermediateDirectories: true)

        // Dark theme: dark background, light text
        let dark = "background = #282828\nforeground = #ebdbb2\n"
        // Light theme: light background, dark text
        let light = "background = #fbf1c7\nforeground = #3c3836\n"

        try? dark.write(toFile: themesDir + "/demo-dark", atomically: true, encoding: .utf8)
        try? light.write(toFile: themesDir + "/demo-light", atomically: true, encoding: .utf8)

        // Config that references both themes conditionally
        let config = "theme = light:demo-light,dark:demo-dark\n"
        let configPath = tmpDir + "/config"
        try? config.write(toFile: configPath, atomically: true, encoding: .utf8)

        return configPath
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configPath = createThemeConfig()
        do {
            try GhosttyEngine.shared.initialize(config: TerminalConfiguration(
                fontSize: 14,
                customConfigPath: configPath
            ))
        } catch {
            NSLog("Failed to initialize ghostty engine: \(error)")
            NSApp.terminate(nil)
            return
        }

        // Build main menu
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit BasicTerminal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Appearance", action: #selector(toggleAppearance), keyEquivalent: "t")
        viewMenuItem.submenu = viewMenu

        NSApp.mainMenu = mainMenu

        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BasicTerminal"
        window.center()
        window.minSize = NSSize(width: 200, height: 100)

        terminal = LocalProcessTerminalView(
            frame: window.contentView!.bounds,
            configuration: TerminalConfiguration(fontSize: 14)
        )
        terminal.autoresizingMask = [.width, .height]
        terminal.delegate = self

        window.contentView = terminal
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(terminal)

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleAppearance() {
        isDarkMode.toggle()
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
    }

    // MARK: - NSApplicationDelegate

    func applicationDidBecomeActive(_ notification: Notification) {
        GhosttyEngine.shared.setFocus(true)
    }

    func applicationDidResignActive(_ notification: Notification) {
        GhosttyEngine.shared.setFocus(false)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - TerminalViewDelegate

    func setTerminalTitle(source: TerminalView, title: String) {
        window.title = title
    }

    func processExited(source: TerminalView, exitCode: UInt32, runtimeMs: UInt64) {
        NSApp.terminate(nil)
    }

    func surfaceClosed(source: TerminalView, processAlive: Bool) {
        NSApp.terminate(nil)
    }
}
