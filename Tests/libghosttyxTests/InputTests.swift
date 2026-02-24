import XCTest
import Carbon.HIToolbox
@testable import libghosttyx
import libghostty

final class InputTests: XCTestCase {
    func testGhosttyKeyMapping() {
        // Letters
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_ANSI_A)), GHOSTTY_KEY_A)
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_ANSI_Z)), GHOSTTY_KEY_Z)

        // Digits
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_ANSI_0)), GHOSTTY_KEY_DIGIT_0)
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_ANSI_9)), GHOSTTY_KEY_DIGIT_9)

        // Special keys
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_Return)), GHOSTTY_KEY_ENTER)
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_Tab)), GHOSTTY_KEY_TAB)
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_Space)), GHOSTTY_KEY_SPACE)
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_Delete)), GHOSTTY_KEY_BACKSPACE)
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_Escape)), GHOSTTY_KEY_ESCAPE)

        // Arrow keys
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_UpArrow)), GHOSTTY_KEY_ARROW_UP)
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_DownArrow)), GHOSTTY_KEY_ARROW_DOWN)
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_LeftArrow)), GHOSTTY_KEY_ARROW_LEFT)
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_RightArrow)), GHOSTTY_KEY_ARROW_RIGHT)

        // Function keys
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_F1)), GHOSTTY_KEY_F1)
        XCTAssertEqual(ghosttyKey(from: UInt16(kVK_F12)), GHOSTTY_KEY_F12)

        // Unknown key
        XCTAssertEqual(ghosttyKey(from: 0xFF), GHOSTTY_KEY_UNIDENTIFIED)
    }

    func testMouseButtonMapping() {
        XCTAssertEqual(ghosttyMouseButton(0), GHOSTTY_MOUSE_LEFT)
        XCTAssertEqual(ghosttyMouseButton(1), GHOSTTY_MOUSE_RIGHT)
        XCTAssertEqual(ghosttyMouseButton(2), GHOSTTY_MOUSE_MIDDLE)
        XCTAssertEqual(ghosttyMouseButton(3), GHOSTTY_MOUSE_FOUR)
        XCTAssertEqual(ghosttyMouseButton(99), GHOSTTY_MOUSE_UNKNOWN)
    }

    func testScrollMods() {
        // No precision, no momentum
        let mods1 = ghosttyScrollMods(precision: false, momentumPhase: GHOSTTY_MOUSE_MOMENTUM_NONE)
        XCTAssertEqual(mods1, 0)

        // Precision, no momentum
        let mods2 = ghosttyScrollMods(precision: true, momentumPhase: GHOSTTY_MOUSE_MOMENTUM_NONE)
        XCTAssertEqual(mods2, 1)

        // No precision, with momentum
        let mods3 = ghosttyScrollMods(precision: false, momentumPhase: GHOSTTY_MOUSE_MOMENTUM_BEGAN)
        XCTAssertEqual(mods3 & 1, 0)  // precision bit is 0
        XCTAssertTrue(mods3 > 0)       // momentum bits are set

        // Precision + momentum
        let mods4 = ghosttyScrollMods(precision: true, momentumPhase: GHOSTTY_MOUSE_MOMENTUM_CHANGED)
        XCTAssertEqual(mods4 & 1, 1)  // precision bit is set
    }
}
