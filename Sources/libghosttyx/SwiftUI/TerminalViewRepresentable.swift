import SwiftUI

/// A SwiftUI wrapper around `TerminalView`.
///
/// ## Usage
/// ```swift
/// @main struct MyApp: App {
///     init() { try! GhosttyEngine.shared.initialize() }
///     var body: some Scene {
///         WindowGroup {
///             TerminalViewRepresentable(configuration: .init(fontSize: 13))
///         }
///     }
/// }
/// ```
@available(macOS 13.0, *)
public struct TerminalViewRepresentable: NSViewRepresentable {
    public typealias NSViewType = LocalProcessTerminalView

    private let configuration: TerminalConfiguration
    private let colorScheme: ColorScheme?
    private let onEvent: ((TerminalEvent) -> Void)?

    /// Events that can be observed from SwiftUI.
    public enum TerminalEvent {
        case titleChanged(String)
        case bell
        case processExited(exitCode: UInt32)
        case workingDirectoryChanged(String)
    }

    /// Creates a terminal view representable.
    ///
    /// - Parameters:
    ///   - configuration: Terminal configuration.
    ///   - colorScheme: Explicit color scheme override. When `nil` (the default),
    ///     the terminal follows the system appearance automatically.
    ///   - onEvent: Optional closure called for terminal events.
    public init(
        configuration: TerminalConfiguration = .init(),
        colorScheme: ColorScheme? = nil,
        onEvent: ((TerminalEvent) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.colorScheme = colorScheme
        self.onEvent = onEvent
    }

    public func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero, configuration: configuration)
        view.delegate = context.coordinator
        return view
    }

    public func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        if let colorScheme {
            nsView.setColorScheme(dark: colorScheme == .dark)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    @MainActor
    public class Coordinator: NSObject, TerminalViewDelegate {
        let onEvent: ((TerminalEvent) -> Void)?

        init(onEvent: ((TerminalEvent) -> Void)?) {
            self.onEvent = onEvent
        }

        public func setTerminalTitle(source: TerminalView, title: String) {
            onEvent?(.titleChanged(title))
        }

        public func bell(source: TerminalView) {
            onEvent?(.bell)
            NSSound.beep()
        }

        public func processExited(source: TerminalView, exitCode: UInt32, runtimeMs: UInt64) {
            onEvent?(.processExited(exitCode: exitCode))
        }

        public func workingDirectoryChanged(source: TerminalView, directory: String) {
            onEvent?(.workingDirectoryChanged(directory))
        }
    }
}
