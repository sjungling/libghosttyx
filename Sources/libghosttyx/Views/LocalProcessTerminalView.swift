import AppKit

/// A convenience subclass of `TerminalView` that automatically starts
/// a terminal session when the view is added to a window.
///
/// This is the simplest way to embed a terminal:
/// ```swift
/// let terminal = LocalProcessTerminalView(frame: bounds)
/// terminal.delegate = self
/// window.contentView = terminal
/// ```
///
/// libghostty handles PTY creation and shell spawning internally.
@MainActor
open class LocalProcessTerminalView: TerminalView {
    /// Configuration to use when auto-starting.
    private var pendingConfiguration: TerminalConfiguration

    /// Whether to automatically start when moved to a window.
    public var autoStart: Bool = true

    public init(frame: NSRect, configuration: TerminalConfiguration = .init()) {
        self.pendingConfiguration = configuration
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        self.pendingConfiguration = TerminalConfiguration()
        super.init(coder: coder)
    }

    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Auto-start when we have a window and haven't started yet
        if window != nil && !isRunning && autoStart {
            do {
                try startTerminal(configuration: pendingConfiguration)
            } catch {
                NSLog("[libghosttyx] Failed to auto-start terminal: \(error)")
            }
        }
    }
}
