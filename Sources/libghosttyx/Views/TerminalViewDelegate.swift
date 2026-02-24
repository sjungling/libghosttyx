import AppKit

/// Protocol for receiving callbacks from a `TerminalView`.
///
/// Modeled after SwiftTerm's `TerminalViewDelegate` for familiarity.
/// All methods have default (no-op) implementations.
@MainActor
public protocol TerminalViewDelegate: AnyObject {
    /// Called when the terminal title changes (via escape sequence).
    func setTerminalTitle(source: TerminalView, title: String)

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
}

// MARK: - Default Implementations

public extension TerminalViewDelegate {
    func setTerminalTitle(source: TerminalView, title: String) {}
    func bell(source: TerminalView) { NSSound.beep() }
    func sizeChanged(source: TerminalView, newCols: UInt16, newRows: UInt16) {}
    func scrolled(source: TerminalView, position: (total: UInt64, offset: UInt64, length: UInt64)) {}
    func clipboardCopy(source: TerminalView, content: String) {}
    func workingDirectoryChanged(source: TerminalView, directory: String) {}
    func requestOpenLink(source: TerminalView, url: URL) {
        NSWorkspace.shared.open(url)
    }
    func processExited(source: TerminalView, exitCode: UInt32, runtimeMs: UInt64) {}
    func surfaceClosed(source: TerminalView, processAlive: Bool) {}
    func desktopNotification(source: TerminalView, title: String, body: String) {}
    func mouseShapeChanged(source: TerminalView, shape: Int) {}
    func colorChanged(source: TerminalView, kind: Int, r: UInt8, g: UInt8, b: UInt8) {}
}
