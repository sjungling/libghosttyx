import AppKit
import XCTest
import libghostty
@testable import libghosttyx

@MainActor
final class OSC8LinkTests: XCTestCase {

    private class LinkDelegate: TerminalViewDelegate {
        var hovered: String?
        var opened: [(url: URL, kind: OpenURLKind)] = []

        func mouseOverLink(source: TerminalView, url: String?) { hovered = url }
        func requestOpenLink(source: TerminalView, url: URL, kind: OpenURLKind) {
            opened.append((url, kind))
        }
    }

    private func pump(until condition: () -> Bool, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    func testCmdClickOnOSC8LinkReportsOSC8Kind() throws {
        do {
            try GhosttyEngine.shared.initialize()
        } catch GhosttyError.alreadyInitialized {
        } catch {
            throw XCTSkip("GhosttyEngine not available: \(error)")
        }

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("osc8-\(UUID().uuidString).sh")
        try #"printf '\033]8;;https://example.com/osc8\033\\LINKTEXT\033]8;;\033\\\n'; sleep 10"#
            .write(to: scriptURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: scriptURL) }
        let view = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let delegate = LinkDelegate()
        view.delegate = delegate
        do {
            try view.startTerminal(
                configuration: TerminalConfiguration(command: "/bin/sh \(scriptURL.path)"))
        } catch {
            throw XCTSkip("Surface creation not available in test environment: \(error)")
        }
        defer { view.close() }

        let surface = try XCTUnwrap(view.surface)
        pump(until: { view.readLineText(row: 0)?.contains("LINKTEXT") == true }, timeout: 3)
        let mods = ghostty_input_mods_e(rawValue: GHOSTTY_MODS_SUPER.rawValue)

        // The login shell prints a banner first, so the link is not on row 0; sweep down
        // the left edge until the hover lands on it (avoids assuming pixel vs point units).
        var y = 2.0
        pump(until: {
            surface.sendMousePos(x: 4, y: y, mods: mods)
            if delegate.hovered == nil { y += 3 }
            return delegate.hovered != nil || y > 160
        })
        XCTAssertEqual(delegate.hovered, "https://example.com/osc8")

        surface.sendMouseButton(GHOSTTY_MOUSE_PRESS, button: GHOSTTY_MOUSE_LEFT, mods: mods)
        surface.sendMouseButton(GHOSTTY_MOUSE_RELEASE, button: GHOSTTY_MOUSE_LEFT, mods: mods)
        pump(until: { !delegate.opened.isEmpty })

        XCTAssertEqual(delegate.opened.first?.url.absoluteString, "https://example.com/osc8")
        XCTAssertEqual(delegate.opened.first?.kind, .osc8)
    }
}
