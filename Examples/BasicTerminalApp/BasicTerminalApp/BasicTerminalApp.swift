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

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try GhosttyEngine.shared.initialize(config: TerminalConfiguration(
                fontSize: 14
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

        let terminal = LocalProcessTerminalView(
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
