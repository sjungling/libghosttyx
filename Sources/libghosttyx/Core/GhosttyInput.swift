import AppKit
import Carbon.HIToolbox
import libghostty

// MARK: - Modifier Translation

// Raw device modifier masks for sided modifier detection.
// These come from IOKit/IOLLEvent.h but aren't always available in Swift.
private let kNXDeviceRShiftKeyMask: UInt = 0x00000004
private let kNXDeviceRCtlKeyMask: UInt = 0x00002000
private let kNXDeviceRAltKeyMask: UInt = 0x00000040
private let kNXDeviceRCmdKeyMask: UInt = 0x00000010

/// Converts AppKit modifier flags to ghostty modifier bitmask.
public func ghosttyMods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
    var mods = GHOSTTY_MODS_NONE.rawValue

    if flags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
    if flags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
    if flags.contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
    if flags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
    if flags.contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }

    // Sided modifiers from raw value
    let raw = flags.rawValue
    if raw & kNXDeviceRShiftKeyMask != 0 { mods |= GHOSTTY_MODS_SHIFT_RIGHT.rawValue }
    if raw & kNXDeviceRCtlKeyMask != 0 { mods |= GHOSTTY_MODS_CTRL_RIGHT.rawValue }
    if raw & kNXDeviceRAltKeyMask != 0 { mods |= GHOSTTY_MODS_ALT_RIGHT.rawValue }
    if raw & kNXDeviceRCmdKeyMask != 0 { mods |= GHOSTTY_MODS_SUPER_RIGHT.rawValue }

    return ghostty_input_mods_e(mods)
}

// MARK: - macOS Keycode to Ghostty Key

/// Maps a macOS CGKeyCode (from NSEvent.keyCode) to the corresponding ghostty key.
///
/// Based on the W3C UIEvents key codes that Ghostty uses internally.
/// The macOS virtual key codes are defined in `Events.h` / `Carbon.framework`.
public func ghosttyKey(from keyCode: UInt16) -> ghostty_input_key_e {
    switch Int(keyCode) {
    // Letters
    case kVK_ANSI_A: return GHOSTTY_KEY_A
    case kVK_ANSI_B: return GHOSTTY_KEY_B
    case kVK_ANSI_C: return GHOSTTY_KEY_C
    case kVK_ANSI_D: return GHOSTTY_KEY_D
    case kVK_ANSI_E: return GHOSTTY_KEY_E
    case kVK_ANSI_F: return GHOSTTY_KEY_F
    case kVK_ANSI_G: return GHOSTTY_KEY_G
    case kVK_ANSI_H: return GHOSTTY_KEY_H
    case kVK_ANSI_I: return GHOSTTY_KEY_I
    case kVK_ANSI_J: return GHOSTTY_KEY_J
    case kVK_ANSI_K: return GHOSTTY_KEY_K
    case kVK_ANSI_L: return GHOSTTY_KEY_L
    case kVK_ANSI_M: return GHOSTTY_KEY_M
    case kVK_ANSI_N: return GHOSTTY_KEY_N
    case kVK_ANSI_O: return GHOSTTY_KEY_O
    case kVK_ANSI_P: return GHOSTTY_KEY_P
    case kVK_ANSI_Q: return GHOSTTY_KEY_Q
    case kVK_ANSI_R: return GHOSTTY_KEY_R
    case kVK_ANSI_S: return GHOSTTY_KEY_S
    case kVK_ANSI_T: return GHOSTTY_KEY_T
    case kVK_ANSI_U: return GHOSTTY_KEY_U
    case kVK_ANSI_V: return GHOSTTY_KEY_V
    case kVK_ANSI_W: return GHOSTTY_KEY_W
    case kVK_ANSI_X: return GHOSTTY_KEY_X
    case kVK_ANSI_Y: return GHOSTTY_KEY_Y
    case kVK_ANSI_Z: return GHOSTTY_KEY_Z

    // Digits
    case kVK_ANSI_0: return GHOSTTY_KEY_DIGIT_0
    case kVK_ANSI_1: return GHOSTTY_KEY_DIGIT_1
    case kVK_ANSI_2: return GHOSTTY_KEY_DIGIT_2
    case kVK_ANSI_3: return GHOSTTY_KEY_DIGIT_3
    case kVK_ANSI_4: return GHOSTTY_KEY_DIGIT_4
    case kVK_ANSI_5: return GHOSTTY_KEY_DIGIT_5
    case kVK_ANSI_6: return GHOSTTY_KEY_DIGIT_6
    case kVK_ANSI_7: return GHOSTTY_KEY_DIGIT_7
    case kVK_ANSI_8: return GHOSTTY_KEY_DIGIT_8
    case kVK_ANSI_9: return GHOSTTY_KEY_DIGIT_9

    // Punctuation / symbols
    case kVK_ANSI_Grave: return GHOSTTY_KEY_BACKQUOTE
    case kVK_ANSI_Minus: return GHOSTTY_KEY_MINUS
    case kVK_ANSI_Equal: return GHOSTTY_KEY_EQUAL
    case kVK_ANSI_LeftBracket: return GHOSTTY_KEY_BRACKET_LEFT
    case kVK_ANSI_RightBracket: return GHOSTTY_KEY_BRACKET_RIGHT
    case kVK_ANSI_Backslash: return GHOSTTY_KEY_BACKSLASH
    case kVK_ANSI_Semicolon: return GHOSTTY_KEY_SEMICOLON
    case kVK_ANSI_Quote: return GHOSTTY_KEY_QUOTE
    case kVK_ANSI_Comma: return GHOSTTY_KEY_COMMA
    case kVK_ANSI_Period: return GHOSTTY_KEY_PERIOD
    case kVK_ANSI_Slash: return GHOSTTY_KEY_SLASH

    // Function / control keys
    case kVK_Return: return GHOSTTY_KEY_ENTER
    case kVK_Tab: return GHOSTTY_KEY_TAB
    case kVK_Space: return GHOSTTY_KEY_SPACE
    case kVK_Delete: return GHOSTTY_KEY_BACKSPACE
    case kVK_Escape: return GHOSTTY_KEY_ESCAPE
    case kVK_CapsLock: return GHOSTTY_KEY_CAPS_LOCK

    // Modifier keys
    case kVK_Shift: return GHOSTTY_KEY_SHIFT_LEFT
    case kVK_RightShift: return GHOSTTY_KEY_SHIFT_RIGHT
    case kVK_Control: return GHOSTTY_KEY_CONTROL_LEFT
    case kVK_RightControl: return GHOSTTY_KEY_CONTROL_RIGHT
    case kVK_Option: return GHOSTTY_KEY_ALT_LEFT
    case kVK_RightOption: return GHOSTTY_KEY_ALT_RIGHT
    case kVK_Command: return GHOSTTY_KEY_META_LEFT
    case 0x36: return GHOSTTY_KEY_META_RIGHT  // kVK_RightCommand

    // Arrow keys
    case kVK_UpArrow: return GHOSTTY_KEY_ARROW_UP
    case kVK_DownArrow: return GHOSTTY_KEY_ARROW_DOWN
    case kVK_LeftArrow: return GHOSTTY_KEY_ARROW_LEFT
    case kVK_RightArrow: return GHOSTTY_KEY_ARROW_RIGHT

    // Navigation
    case kVK_Home: return GHOSTTY_KEY_HOME
    case kVK_End: return GHOSTTY_KEY_END
    case kVK_PageUp: return GHOSTTY_KEY_PAGE_UP
    case kVK_PageDown: return GHOSTTY_KEY_PAGE_DOWN
    case kVK_ForwardDelete: return GHOSTTY_KEY_DELETE
    case kVK_Help: return GHOSTTY_KEY_INSERT

    // Function keys
    case kVK_F1: return GHOSTTY_KEY_F1
    case kVK_F2: return GHOSTTY_KEY_F2
    case kVK_F3: return GHOSTTY_KEY_F3
    case kVK_F4: return GHOSTTY_KEY_F4
    case kVK_F5: return GHOSTTY_KEY_F5
    case kVK_F6: return GHOSTTY_KEY_F6
    case kVK_F7: return GHOSTTY_KEY_F7
    case kVK_F8: return GHOSTTY_KEY_F8
    case kVK_F9: return GHOSTTY_KEY_F9
    case kVK_F10: return GHOSTTY_KEY_F10
    case kVK_F11: return GHOSTTY_KEY_F11
    case kVK_F12: return GHOSTTY_KEY_F12
    case kVK_F13: return GHOSTTY_KEY_F13
    case kVK_F14: return GHOSTTY_KEY_F14
    case kVK_F15: return GHOSTTY_KEY_F15
    case kVK_F16: return GHOSTTY_KEY_F16
    case kVK_F17: return GHOSTTY_KEY_F17
    case kVK_F18: return GHOSTTY_KEY_F18
    case kVK_F19: return GHOSTTY_KEY_F19
    case kVK_F20: return GHOSTTY_KEY_F20

    // Numpad
    case kVK_ANSI_Keypad0: return GHOSTTY_KEY_NUMPAD_0
    case kVK_ANSI_Keypad1: return GHOSTTY_KEY_NUMPAD_1
    case kVK_ANSI_Keypad2: return GHOSTTY_KEY_NUMPAD_2
    case kVK_ANSI_Keypad3: return GHOSTTY_KEY_NUMPAD_3
    case kVK_ANSI_Keypad4: return GHOSTTY_KEY_NUMPAD_4
    case kVK_ANSI_Keypad5: return GHOSTTY_KEY_NUMPAD_5
    case kVK_ANSI_Keypad6: return GHOSTTY_KEY_NUMPAD_6
    case kVK_ANSI_Keypad7: return GHOSTTY_KEY_NUMPAD_7
    case kVK_ANSI_Keypad8: return GHOSTTY_KEY_NUMPAD_8
    case kVK_ANSI_Keypad9: return GHOSTTY_KEY_NUMPAD_9
    case kVK_ANSI_KeypadDecimal: return GHOSTTY_KEY_NUMPAD_DECIMAL
    case kVK_ANSI_KeypadPlus: return GHOSTTY_KEY_NUMPAD_ADD
    case kVK_ANSI_KeypadMinus: return GHOSTTY_KEY_NUMPAD_SUBTRACT
    case kVK_ANSI_KeypadMultiply: return GHOSTTY_KEY_NUMPAD_MULTIPLY
    case kVK_ANSI_KeypadDivide: return GHOSTTY_KEY_NUMPAD_DIVIDE
    case kVK_ANSI_KeypadEnter: return GHOSTTY_KEY_NUMPAD_ENTER
    case kVK_ANSI_KeypadEquals: return GHOSTTY_KEY_NUMPAD_EQUAL
    case kVK_ANSI_KeypadClear: return GHOSTTY_KEY_NUM_LOCK

    default: return GHOSTTY_KEY_UNIDENTIFIED
    }
}

// MARK: - Mouse Button Translation

/// Converts an AppKit mouse button number to the ghostty mouse button enum.
public func ghosttyMouseButton(_ buttonNumber: Int) -> ghostty_input_mouse_button_e {
    switch buttonNumber {
    case 0: return GHOSTTY_MOUSE_LEFT
    case 1: return GHOSTTY_MOUSE_RIGHT
    case 2: return GHOSTTY_MOUSE_MIDDLE
    case 3: return GHOSTTY_MOUSE_FOUR
    case 4: return GHOSTTY_MOUSE_FIVE
    case 5: return GHOSTTY_MOUSE_SIX
    case 6: return GHOSTTY_MOUSE_SEVEN
    case 7: return GHOSTTY_MOUSE_EIGHT
    default: return GHOSTTY_MOUSE_UNKNOWN
    }
}

// MARK: - Scroll Mods

/// Constructs a ghostty scroll mods value from precision and momentum phase.
///
/// Bit layout:
///   - bit 0: precision (1 = high-precision trackpad)
///   - bits 1-3: momentum phase
public func ghosttyScrollMods(
    precision: Bool,
    momentumPhase: ghostty_input_mouse_momentum_e
) -> ghostty_input_scroll_mods_t {
    var mods: Int32 = 0
    if precision { mods |= 1 }
    mods |= Int32(momentumPhase.rawValue) << 1
    return mods
}

/// Maps NSEvent momentum phase to ghostty momentum phase.
public func ghosttyMomentumPhase(_ phase: NSEvent.Phase) -> ghostty_input_mouse_momentum_e {
    switch phase {
    case .began: return GHOSTTY_MOUSE_MOMENTUM_BEGAN
    case .stationary: return GHOSTTY_MOUSE_MOMENTUM_STATIONARY
    case .changed: return GHOSTTY_MOUSE_MOMENTUM_CHANGED
    case .ended: return GHOSTTY_MOUSE_MOMENTUM_ENDED
    case .cancelled: return GHOSTTY_MOUSE_MOMENTUM_CANCELLED
    case .mayBegin: return GHOSTTY_MOUSE_MOMENTUM_MAY_BEGIN
    default: return GHOSTTY_MOUSE_MOMENTUM_NONE
    }
}
