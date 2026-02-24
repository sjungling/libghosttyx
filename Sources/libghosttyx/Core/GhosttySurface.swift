import AppKit
import libghostty

/// Swift wrapper around `ghostty_surface_t`.
///
/// Manages the lifecycle of a single terminal surface and provides
/// Swift-friendly methods for input, display, and lifecycle management.
@MainActor
public final class GhosttySurface {
    private(set) var rawSurface: ghostty_surface_t?

    /// Creates a new surface under the given app with the specified config.
    init(app: ghostty_app_t, config: inout ghostty_surface_config_s) throws {
        guard let surface = ghostty_surface_new(app, &config) else {
            throw GhosttyError.surfaceCreationFailed
        }
        rawSurface = surface
    }

    deinit {
        if let surface = rawSurface {
            ghostty_surface_free(surface)
        }
    }

    /// Retrieves the userdata pointer associated with this surface.
    var userdata: UnsafeMutableRawPointer? {
        guard let surface = rawSurface else { return nil }
        return ghostty_surface_userdata(surface)
    }

    // MARK: - Display Properties

    /// Sets the content scale factor (e.g. for Retina displays).
    func setContentScale(_ scale: Double) {
        guard let surface = rawSurface else { return }
        ghostty_surface_set_content_scale(surface, scale, scale)
    }

    /// Sets whether the surface has keyboard focus.
    func setFocus(_ focused: Bool) {
        guard let surface = rawSurface else { return }
        ghostty_surface_set_focus(surface, focused)
    }

    /// Sets whether the surface is occluded (hidden behind other windows).
    func setOcclusion(_ occluded: Bool) {
        guard let surface = rawSurface else { return }
        ghostty_surface_set_occlusion(surface, occluded)
    }

    /// Sets the surface size in pixels.
    func setSize(width: UInt32, height: UInt32) {
        guard let surface = rawSurface else { return }
        ghostty_surface_set_size(surface, width, height)
    }

    /// Gets the current surface size (columns, rows, pixel dimensions).
    var size: ghostty_surface_size_s? {
        guard let surface = rawSurface else { return nil }
        return ghostty_surface_size(surface)
    }

    /// Sets the color scheme (light/dark).
    func setColorScheme(_ scheme: ghostty_color_scheme_e) {
        guard let surface = rawSurface else { return }
        ghostty_surface_set_color_scheme(surface, scheme)
    }

    /// Sets the display ID (macOS-specific, for display changes).
    func setDisplayID(_ displayID: UInt32) {
        guard let surface = rawSurface else { return }
        ghostty_surface_set_display_id(surface, displayID)
    }

    // MARK: - Rendering

    /// Triggers a refresh callback.
    func refresh() {
        guard let surface = rawSurface else { return }
        ghostty_surface_refresh(surface)
    }

    // MARK: - Key Input

    /// Sends a key event to the surface.
    @discardableResult
    func sendKey(_ event: ghostty_input_key_s) -> Bool {
        guard let surface = rawSurface else { return false }
        return ghostty_surface_key(surface, event)
    }

    /// Checks if a key event would trigger a binding.
    func keyIsBinding(_ event: ghostty_input_key_s) -> (Bool, ghostty_binding_flags_e?) {
        guard let surface = rawSurface else { return (false, nil) }
        var flags = ghostty_binding_flags_e(0)
        let isBinding = ghostty_surface_key_is_binding(surface, event, &flags)
        return (isBinding, isBinding ? flags : nil)
    }

    /// Gets translation modifiers for proper key handling.
    func keyTranslationMods(_ mods: ghostty_input_mods_e) -> ghostty_input_mods_e {
        guard let surface = rawSurface else { return mods }
        return ghostty_surface_key_translation_mods(surface, mods)
    }

    /// Sends text input (from IME or direct typing).
    func sendText(_ text: String) {
        guard let surface = rawSurface else { return }
        text.withCString { ptr in
            ghostty_surface_text(surface, ptr, UInt(text.utf8.count))
        }
    }

    /// Sends preedit text (IME composition in progress).
    func sendPreedit(_ text: String?) {
        guard let surface = rawSurface else { return }
        if let text = text {
            text.withCString { ptr in
                ghostty_surface_preedit(surface, ptr, UInt(text.utf8.count))
            }
        } else {
            ghostty_surface_preedit(surface, nil, 0)
        }
    }

    // MARK: - Mouse Input

    /// Sends a mouse button event.
    @discardableResult
    func sendMouseButton(
        _ state: ghostty_input_mouse_state_e,
        button: ghostty_input_mouse_button_e,
        mods: ghostty_input_mods_e
    ) -> Bool {
        guard let surface = rawSurface else { return false }
        return ghostty_surface_mouse_button(surface, state, button, mods)
    }

    /// Sends a mouse position update.
    func sendMousePos(x: Double, y: Double, mods: ghostty_input_mods_e) {
        guard let surface = rawSurface else { return }
        ghostty_surface_mouse_pos(surface, x, y, mods)
    }

    /// Sends a scroll event.
    func sendMouseScroll(x: Double, y: Double, mods: ghostty_input_scroll_mods_t) {
        guard let surface = rawSurface else { return }
        ghostty_surface_mouse_scroll(surface, x, y, mods)
    }

    /// Sends a pressure event (Force Touch).
    func sendMousePressure(stage: UInt32, pressure: Double) {
        guard let surface = rawSurface else { return }
        ghostty_surface_mouse_pressure(surface, stage, pressure)
    }

    /// Whether the surface is currently capturing mouse events.
    var mouseCaptured: Bool {
        guard let surface = rawSurface else { return false }
        return ghostty_surface_mouse_captured(surface)
    }

    // MARK: - IME

    /// Gets the IME cursor position for the input method editor.
    func imePoint() -> (x: Double, y: Double, width: Double, height: Double) {
        guard let surface = rawSurface else { return (0, 0, 0, 0) }
        var x: Double = 0, y: Double = 0, w: Double = 0, h: Double = 0
        ghostty_surface_ime_point(surface, &x, &y, &w, &h)
        return (x, y, w, h)
    }

    // MARK: - Lifecycle

    /// Requests the surface to close.
    func requestClose() {
        guard let surface = rawSurface else { return }
        ghostty_surface_request_close(surface)
    }

    /// Whether the child process has exited.
    var processExited: Bool {
        guard let surface = rawSurface else { return true }
        return ghostty_surface_process_exited(surface)
    }

    /// Whether the surface needs to confirm before quitting.
    var needsConfirmQuit: Bool {
        guard let surface = rawSurface else { return false }
        return ghostty_surface_needs_confirm_quit(surface)
    }

    // MARK: - Selection / Clipboard

    /// Whether the surface has an active text selection.
    var hasSelection: Bool {
        guard let surface = rawSurface else { return false }
        return ghostty_surface_has_selection(surface)
    }

    /// Completes a clipboard read request from libghostty.
    func completeClipboardRequest(
        data: String?,
        state: UnsafeMutableRawPointer?,
        confirmed: Bool
    ) {
        guard let surface = rawSurface else { return }
        if let data = data {
            data.withCString { ptr in
                ghostty_surface_complete_clipboard_request(surface, ptr, state, confirmed)
            }
        } else {
            ghostty_surface_complete_clipboard_request(surface, nil, state, confirmed)
        }
    }

    // MARK: - Config

    /// Updates the surface with new config.
    func updateConfig(_ config: ghostty_config_t) {
        guard let surface = rawSurface else { return }
        ghostty_surface_update_config(surface, config)
    }
}
