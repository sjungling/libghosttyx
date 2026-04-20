import AppKit
import libghostty

/// Protocol for receiving callbacks from a `TerminalView`.
///
/// Modeled after SwiftTerm's `TerminalViewDelegate` for familiarity.
/// All methods have default (no-op) implementations.
@MainActor
public protocol TerminalViewDelegate: AnyObject {
    /// Called when the terminal title changes (via escape sequence).
    func setTerminalTitle(source: TerminalView, title: String)

    /// Called when the terminal tab title changes (via `set_tab_title` binding action).
    func setTabTitle(source: TerminalView, title: String)

    /// Called when the terminal rings the bell.
    func bell(source: TerminalView)

    /// Called when the terminal cell size changes.
    func sizeChanged(source: TerminalView, newCols: UInt16, newRows: UInt16)

    /// Called when the scroll position changes.
    func scrolled(source: TerminalView, position: (total: UInt64, offset: UInt64, length: UInt64))

    /// Called when the terminal copies content to the clipboard.
    func clipboardCopy(source: TerminalView, content: String)

    /// Called when the terminal's working directory changes.
    func workingDirectoryChanged(source: TerminalView, directory: String)

    /// Called when the terminal requests opening a URL.
    func requestOpenLink(source: TerminalView, url: URL)

    /// Called when the mouse hovers over or leaves an OSC 8 hyperlink.
    /// - Parameter url: The hyperlink URI, or nil when the mouse leaves the link.
    func mouseOverLink(source: TerminalView, url: String?)

    /// Called when the terminal's child process exits.
    func processExited(source: TerminalView, exitCode: UInt32, runtimeMs: UInt64)

    /// Called when the terminal surface is closed.
    func surfaceClosed(source: TerminalView, processAlive: Bool)

    /// Called when a desktop notification is requested.
    func desktopNotification(source: TerminalView, title: String, body: String)

    /// Called when the mouse cursor shape should change.
    func mouseShapeChanged(source: TerminalView, shape: Int)

    /// Called when the terminal color scheme changes.
    func colorChanged(source: TerminalView, kind: Int, r: UInt8, g: UInt8, b: UInt8)

    /// Called when the terminal requests the mouse cursor be shown or hidden.
    func mouseVisibilityChanged(source: TerminalView, visible: Bool)

    /// Called when secure input mode changes (e.g. a password prompt via sudo).
    func secureInputChanged(source: TerminalView, enabled: Bool)

    /// Called when Ghostty sets size constraints for the terminal.
    func sizeLimitChanged(source: TerminalView, minCols: UInt32, minRows: UInt32, maxCols: UInt32, maxRows: UInt32)

    /// Called when Ghostty requests an initial terminal size.
    func initialSizeRequested(source: TerminalView, cols: UInt32, rows: UInt32)

    /// Called when a foreground command reports progress.
    func progressReported(source: TerminalView, state: ghostty_action_progress_report_state_e, progress: Int8)

    /// Called when the GPU renderer health changes.
    func rendererHealthChanged(source: TerminalView, health: ghostty_action_renderer_health_e)
}

// MARK: - Default Implementations

public extension TerminalViewDelegate {
    func setTerminalTitle(source: TerminalView, title: String) {}
    func setTabTitle(source: TerminalView, title: String) {}
    func bell(source: TerminalView) { NSSound.beep() }
    func sizeChanged(source: TerminalView, newCols: UInt16, newRows: UInt16) {}
    func scrolled(source: TerminalView, position: (total: UInt64, offset: UInt64, length: UInt64)) {}
    func clipboardCopy(source: TerminalView, content: String) {}
    func workingDirectoryChanged(source: TerminalView, directory: String) {}
    func requestOpenLink(source: TerminalView, url: URL) {
        NSWorkspace.shared.open(url)
    }
    func mouseOverLink(source: TerminalView, url: String?) {}
    func processExited(source: TerminalView, exitCode: UInt32, runtimeMs: UInt64) {}
    func surfaceClosed(source: TerminalView, processAlive: Bool) {}
    func desktopNotification(source: TerminalView, title: String, body: String) {}
    func mouseShapeChanged(source: TerminalView, shape: Int) {}
    func colorChanged(source: TerminalView, kind: Int, r: UInt8, g: UInt8, b: UInt8) {}
    func mouseVisibilityChanged(source: TerminalView, visible: Bool) {}
    func secureInputChanged(source: TerminalView, enabled: Bool) {}
    func sizeLimitChanged(source: TerminalView, minCols: UInt32, minRows: UInt32, maxCols: UInt32, maxRows: UInt32) {}
    func initialSizeRequested(source: TerminalView, cols: UInt32, rows: UInt32) {}
    func progressReported(source: TerminalView, state: ghostty_action_progress_report_state_e, progress: Int8) {}
    func rendererHealthChanged(source: TerminalView, health: ghostty_action_renderer_health_e) {}
}
