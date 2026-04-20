import XCTest
import libghostty
@testable import libghosttyx

@MainActor
final class ActionHandlingTests: XCTestCase {

    private class MockDelegate: TerminalViewDelegate {
        var mouseVisibility: Bool?
        var secureInputEnabled: Bool?
        var sizeLimitArgs: (minCols: UInt32, minRows: UInt32, maxCols: UInt32, maxRows: UInt32)?
        var initialSizeArgs: (cols: UInt32, rows: UInt32)?
        var progressArgs: (state: ghostty_action_progress_report_state_e, progress: Int8)?
        var rendererHealth: ghostty_action_renderer_health_e?

        func mouseVisibilityChanged(source: TerminalView, visible: Bool) {
            mouseVisibility = visible
        }
        func secureInputChanged(source: TerminalView, enabled: Bool) {
            secureInputEnabled = enabled
        }
        func sizeLimitChanged(source: TerminalView, minCols: UInt32, minRows: UInt32, maxCols: UInt32, maxRows: UInt32) {
            sizeLimitArgs = (minCols, minRows, maxCols, maxRows)
        }
        func initialSizeRequested(source: TerminalView, cols: UInt32, rows: UInt32) {
            initialSizeArgs = (cols, rows)
        }
        func progressReported(source: TerminalView, state: ghostty_action_progress_report_state_e, progress: Int8) {
            progressArgs = (state, progress)
        }
        func rendererHealthChanged(source: TerminalView, health: ghostty_action_renderer_health_e) {
            rendererHealth = health
        }
    }

    private var view: TerminalView!
    private var mock: MockDelegate!

    override func setUp() {
        super.setUp()
        view = TerminalView(frame: .zero)
        mock = MockDelegate()
        view.delegate = mock
    }

    override func tearDown() {
        view = nil
        mock = nil
        super.tearDown()
    }

    func testMouseVisibilityHideNotifiesDelegate() {
        view.handleAction(.mouseVisibility(GHOSTTY_MOUSE_HIDDEN))
        XCTAssertEqual(mock.mouseVisibility, false)
    }

    func testMouseVisibilityShowNotifiesDelegate() {
        view.handleAction(.mouseVisibility(GHOSTTY_MOUSE_VISIBLE))
        XCTAssertEqual(mock.mouseVisibility, true)
    }

    func testSecureInputOnNotifiesDelegate() {
        view.handleAction(.secureInput(GHOSTTY_SECURE_INPUT_ON))
        XCTAssertEqual(mock.secureInputEnabled, true)
    }

    func testSecureInputOffNotifiesDelegate() {
        view.handleAction(.secureInput(GHOSTTY_SECURE_INPUT_OFF))
        XCTAssertEqual(mock.secureInputEnabled, false)
    }

    func testSizeLimitNotifiesDelegate() {
        view.handleAction(.sizeLimit(minWidth: 10, minHeight: 5, maxWidth: 300, maxHeight: 100))
        XCTAssertEqual(mock.sizeLimitArgs?.minCols, 10)
        XCTAssertEqual(mock.sizeLimitArgs?.minRows, 5)
        XCTAssertEqual(mock.sizeLimitArgs?.maxCols, 300)
        XCTAssertEqual(mock.sizeLimitArgs?.maxRows, 100)
    }

    func testInitialSizeNotifiesDelegate() {
        view.handleAction(.initialSize(width: 80, height: 24))
        XCTAssertEqual(mock.initialSizeArgs?.cols, 80)
        XCTAssertEqual(mock.initialSizeArgs?.rows, 24)
    }

    func testProgressReportNotifiesDelegate() {
        view.handleAction(.progressReport(state: GHOSTTY_PROGRESS_STATE_SET, progress: 42))
        XCTAssertEqual(mock.progressArgs?.state, GHOSTTY_PROGRESS_STATE_SET)
        XCTAssertEqual(mock.progressArgs?.progress, 42)
    }

    func testRendererHealthNotifiesDelegate() {
        view.handleAction(.rendererHealth(GHOSTTY_RENDERER_HEALTH_UNHEALTHY))
        XCTAssertEqual(mock.rendererHealth, GHOSTTY_RENDERER_HEALTH_UNHEALTHY)
    }
}
