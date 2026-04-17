import XCTest
import Carbon.HIToolbox
import AppKit
@testable import libghosttyx
import libghostty

@MainActor
final class PasteTests: XCTestCase {

    private class TrackingTerminalView: TerminalView {
        var clipboardRequestHandled = false

        override func handleClipboardRequest(
            type: ghostty_clipboard_e,
            state: UnsafeMutableRawPointer?
        ) {
            clipboardRequestHandled = true
            super.handleClipboardRequest(type: type, state: state)
        }
    }

    private func setUpEngine() throws {
        do {
            try GhosttyEngine.shared.initialize()
        } catch GhosttyError.alreadyInitialized {
            // already initialized from a previous test in this process
        } catch {
            throw XCTSkip("GhosttyEngine not available: \(error)")
        }
    }

    private func makeView() throws -> TrackingTerminalView {
        let view = TrackingTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        do {
            try view.startTerminal()
        } catch {
            throw XCTSkip("Surface creation not available in test environment: \(error)")
        }
        return view
    }

    // RED test: before the readClipboardCallback fix, handleClipboardRequest is
    // dispatched async, so it has NOT been called by the time bindingAction returns.
    // clipboardRequestHandled is still false → assertion fails.
    // GREEN: readClipboardCallback calls handleClipboardRequest synchronously on
    // the main thread, so it is called before bindingAction returns → passes.
    func testClipboardRequestCompletedSynchronously() throws {
        try setUpEngine()
        let view = try makeView()
        defer { view.close() }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("hello from test", forType: .string)

        view.surface?.bindingAction("paste_from_clipboard")

        XCTAssertTrue(
            view.clipboardRequestHandled,
            "readClipboardCallback must complete synchronously on the main thread"
        )
    }

    // Integration: Cmd+V via the normal Ghostty keyboard path (no Swift intercept)
    // must be consumed without crashing.
    func testCmdVHandledWithoutCrash() throws {
        try setUpEngine()
        let view = try makeView()
        defer { view.close() }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("hello from test", forType: .string)

        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "v",
            charactersIgnoringModifiers: "v",
            isARepeat: false,
            keyCode: UInt16(kVK_ANSI_V)
        ) else {
            XCTFail("Could not create Cmd+V key event")
            return
        }

        let handled = view.performKeyEquivalent(with: event)
        XCTAssertTrue(handled, "Cmd+V must be consumed by TerminalView")
    }
}
