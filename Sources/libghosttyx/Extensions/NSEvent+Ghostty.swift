import AppKit
import libghostty

extension NSEvent {
    /// Builds a `ghostty_input_key_s` from this key event.
    ///
    /// - Parameters:
    ///   - action: Whether this is a press, release, or repeat.
    ///   - composing: Whether the key is part of an IME composition.
    /// - Returns: A key event struct ready to pass to `ghostty_surface_key`.
    func ghosttyKeyEvent(
        action: ghostty_input_action_e,
        composing: Bool = false
    ) -> ghostty_input_key_s {
        var event = ghostty_input_key_s()
        event.action = action
        event.mods = libghosttyx.ghosttyMods(modifierFlags)
        event.consumed_mods = ghostty_input_mods_e(0)
        event.keycode = UInt32(keyCode)
        event.composing = composing

        // Compute unshifted codepoint from charactersIgnoringModifiers
        if let chars = charactersIgnoringModifiers, let scalar = chars.unicodeScalars.first {
            event.unshifted_codepoint = scalar.value
        }

        return event
    }

    /// The ghostty key enum value for this event's key code.
    var ghosttyKeyValue: ghostty_input_key_e {
        libghosttyx.ghosttyKey(from: keyCode)
    }

    /// The ghostty modifier bitmask for this event's modifier flags.
    var ghosttyModsValue: ghostty_input_mods_e {
        libghosttyx.ghosttyMods(modifierFlags)
    }
}
