import AppKit
import libghosttyx

/// Minimal macOS app demonstrating embedded terminal.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, TerminalViewDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the ghostty engine
        do {
            try GhosttyEngine.shared.initialize(config: TerminalConfiguration(
                fontSize: 14
            ))
        } catch {
            NSLog("Failed to initialize ghostty engine: \(error)")
            NSApp.terminate(nil)
            return
        }

        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BasicTerminal"
        window.center()

        // Create terminal view
        let terminal = LocalProcessTerminalView(
            frame: window.contentView!.bounds,
            configuration: TerminalConfiguration(fontSize: 14)
        )
        terminal.autoresizingMask = [.width, .height]
        terminal.delegate = self

        window.contentView = terminal
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(terminal)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - TerminalViewDelegate

    func setTerminalTitle(source: TerminalView, title: String) {
        window.title = title
    }

    func processExited(source: TerminalView, exitCode: UInt32, runtimeMs: UInt64) {
        NSLog("Process exited with code \(exitCode)")
        NSApp.terminate(nil)
    }

    func surfaceClosed(source: TerminalView, processAlive: Bool) {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate: AppDelegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
