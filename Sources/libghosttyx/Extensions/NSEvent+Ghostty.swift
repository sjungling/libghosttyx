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
        _ action: ghostty_input_action_e,
        translationMods: NSEvent.ModifierFlags? = nil
    ) -> ghostty_input_key_s {
        var key_ev = ghostty_input_key_s()
        key_ev.action = action
        key_ev.keycode = UInt32(keyCode)
        key_ev.text = nil
        key_ev.composing = false

        // Set modifiers from the event
        key_ev.mods = libghosttyx.ghosttyMods(modifierFlags)

        // Consumed mods: control and command never contribute to text translation
        key_ev.consumed_mods = libghosttyx.ghosttyMods(
            (translationMods ?? modifierFlags)
                .subtracting([.control, .command])
        )

        // Unshifted codepoint: the codepoint with no modifiers applied
        key_ev.unshifted_codepoint = 0
        if type == .keyDown || type == .keyUp {
            if let chars = characters(byApplyingModifiers: []),
               let codepoint = chars.unicodeScalars.first {
                key_ev.unshifted_codepoint = codepoint.value
            }
        }

        return key_ev
    }

    /// Returns the text to set for a key event for Ghostty.
    ///
    /// Contains logic to avoid control characters, since Ghostty handles
    /// control character mapping internally via KeyEncoder.
    var ghosttyCharacters: String? {
        guard let characters else { return nil }

        if characters.count == 1,
           let scalar = characters.unicodeScalars.first {
            // Single control character: return characters without control pressed
            if scalar.value < 0x20 {
                return self.characters(byApplyingModifiers: modifierFlags.subtracting(.control))
            }
            // Private Use Area = function keys, don't send to Ghostty
            if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
                return nil
            }
        }

        return characters
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
