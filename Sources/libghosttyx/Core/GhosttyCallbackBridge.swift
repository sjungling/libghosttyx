import AppKit
import libghostty

/// Provides static C callback trampolines that bridge libghostty's C callbacks
/// to Swift delegate methods.
///
/// These are `@convention(c)` functions that can be stored in `ghostty_runtime_config_s`.
/// They use `Unmanaged` to recover the `GhosttyEngine` (for app-level callbacks)
/// or `TerminalView` (for surface-level callbacks) from the opaque userdata pointers.
enum GhosttyCallbackBridge {
    /// Builds a `ghostty_runtime_config_s` wired to the given engine.
    @MainActor
    static func runtimeConfig(for engine: GhosttyEngine) -> ghostty_runtime_config_s {
        let userdata = Unmanaged.passUnretained(engine).toOpaque()

        return ghostty_runtime_config_s(
            userdata: userdata,
            supports_selection_clipboard: false,
            wakeup_cb: wakeupCallback,
            action_cb: actionCallback,
            read_clipboard_cb: readClipboardCallback,
            confirm_read_clipboard_cb: confirmReadClipboardCallback,
            write_clipboard_cb: writeClipboardCallback,
            close_surface_cb: closeSurfaceCallback
        )
    }

    // MARK: - Wakeup

    /// Called from any thread when libghostty needs attention.
    /// Dispatches `tick()` to the main thread.
    private static let wakeupCallback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { userdata in
        guard let userdata = userdata else { return }
        let engine = Unmanaged<GhosttyEngine>.fromOpaque(userdata).takeUnretainedValue()
        DispatchQueue.main.async {
            engine.tick()
        }
    }

    // MARK: - Action

    /// Routes actions to the appropriate TerminalView delegate or handles app-level actions.
    private static let actionCallback: @convention(c) (
        ghostty_app_t?, ghostty_target_s, ghostty_action_s
    ) -> Bool = { app, target, rawAction in
        let action = GhosttyAction.from(rawAction)

        // For surface-targeted actions, resolve the TerminalView from the surface userdata
        if target.tag == GHOSTTY_TARGET_SURFACE {
            let surface = target.target.surface
            guard let surface = surface,
                  let viewPtr = ghostty_surface_userdata(surface) else {
                return false
            }

            let view = Unmanaged<TerminalView>.fromOpaque(viewPtr).takeUnretainedValue()

            DispatchQueue.main.async {
                view.handleAction(action)
            }

            // Surface-level actions we handle
            switch rawAction.tag {
            case GHOSTTY_ACTION_SET_TITLE,
                 GHOSTTY_ACTION_RING_BELL,
                 GHOSTTY_ACTION_CELL_SIZE,
                 GHOSTTY_ACTION_SCROLLBAR,
                 GHOSTTY_ACTION_PWD,
                 GHOSTTY_ACTION_MOUSE_SHAPE,
                 GHOSTTY_ACTION_MOUSE_VISIBILITY,
                 GHOSTTY_ACTION_RENDER,
                 GHOSTTY_ACTION_COLOR_CHANGE,
                 GHOSTTY_ACTION_OPEN_URL,
                 GHOSTTY_ACTION_SIZE_LIMIT,
                 GHOSTTY_ACTION_INITIAL_SIZE,
                 GHOSTTY_ACTION_DESKTOP_NOTIFICATION,
                 GHOSTTY_ACTION_MOUSE_OVER_LINK,
                 GHOSTTY_ACTION_RENDERER_HEALTH,
                 GHOSTTY_ACTION_SHOW_CHILD_EXITED,
                 GHOSTTY_ACTION_PROGRESS_REPORT,
                 GHOSTTY_ACTION_SECURE_INPUT,
                 GHOSTTY_ACTION_CONFIG_CHANGE,
                 GHOSTTY_ACTION_RELOAD_CONFIG:
                return true
            default:
                break
            }
        }

        // App-level actions — return false so the host app can handle them
        return false
    }

    // MARK: - Clipboard Read

    /// Called when libghostty wants to read the clipboard.
    /// The surface userdata points to the TerminalView.
    private static let readClipboardCallback: @convention(c) (
        UnsafeMutableRawPointer?, ghostty_clipboard_e, UnsafeMutableRawPointer?
    ) -> Void = { userdata, clipboardType, statePtr in
        guard let userdata = userdata else { return }
        let view = Unmanaged<TerminalView>.fromOpaque(userdata).takeUnretainedValue()

        DispatchQueue.main.async {
            let content: String?
            if clipboardType == GHOSTTY_CLIPBOARD_STANDARD {
                content = NSPasteboard.general.string(forType: .string)
            } else {
                content = nil
            }

            view.surface?.completeClipboardRequest(
                data: content,
                state: statePtr,
                confirmed: true
            )
        }
    }

    // MARK: - Confirm Clipboard Read

    /// Called when libghostty wants confirmation before reading clipboard (OSC 52).
    private static let confirmReadClipboardCallback: @convention(c) (
        UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?,
        ghostty_clipboard_request_e
    ) -> Void = { userdata, str, statePtr, requestType in
        guard let userdata = userdata else { return }
        let view = Unmanaged<TerminalView>.fromOpaque(userdata).takeUnretainedValue()

        DispatchQueue.main.async {
            // For now, auto-confirm. Host apps can customize via delegate.
            let content = NSPasteboard.general.string(forType: .string)
            view.surface?.completeClipboardRequest(
                data: content,
                state: statePtr,
                confirmed: true
            )
        }
    }

    // MARK: - Clipboard Write

    /// Called when libghostty wants to write to the clipboard.
    private static let writeClipboardCallback: @convention(c) (
        UnsafeMutableRawPointer?, ghostty_clipboard_e,
        UnsafePointer<ghostty_clipboard_content_s>?, Int, Bool
    ) -> Void = { userdata, clipboardType, content, count, confirm in
        guard clipboardType == GHOSTTY_CLIPBOARD_STANDARD,
              let content = content, count > 0 else { return }

        DispatchQueue.main.async {
            // Use the first content entry
            let entry = content.pointee
            if let dataPtr = entry.data {
                let str = String(cString: dataPtr)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(str, forType: .string)

                // Notify the delegate
                if let userdata = userdata {
                    let view = Unmanaged<TerminalView>.fromOpaque(userdata).takeUnretainedValue()
                    view.delegate?.clipboardCopy(source: view, content: str)
                }
            }
        }
    }

    // MARK: - Close Surface

    /// Called when libghostty wants to close a surface.
    private static let closeSurfaceCallback: @convention(c) (
        UnsafeMutableRawPointer?, Bool
    ) -> Void = { userdata, processAlive in
        guard let userdata = userdata else { return }
        let view = Unmanaged<TerminalView>.fromOpaque(userdata).takeUnretainedValue()

        DispatchQueue.main.async {
            view.delegate?.surfaceClosed(source: view, processAlive: processAlive)
        }
    }
}
