import AppKit
import libghostty

/// Provides static C callback trampolines that bridge libghostty's C callbacks
/// to Swift delegate methods.
///
/// These are `@convention(c)` functions that can be stored in `ghostty_runtime_config_s`.
/// They use `Unmanaged` to recover the `GhosttyEngine` (for app-level callbacks)
/// or `TerminalView` (for surface-level callbacks) from the opaque userdata pointers.
enum GhosttyCallbackBridge {
    /// Guard against infinite recursion when calling `ghostty_surface_update_config`
    /// or `ghostty_app_update_config`. These can fire actions (CONFIG_CHANGE,
    /// RELOAD_CONFIG) that re-enter this callback, causing unbounded recursion.
    /// Thread-safe because all callbacks execute synchronously on the main thread.
    private static var isUpdatingConfig = false
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
        dispatchPrecondition(condition: .onQueue(.main))
        let action = GhosttyAction.from(rawAction)

        // For surface-targeted actions, resolve the TerminalView from the surface userdata
        if target.tag == GHOSTTY_TARGET_SURFACE {
            let surface = target.target.surface
            guard let surface = surface,
                  let viewPtr = ghostty_surface_userdata(surface) else {
                return false
            }

            let view = Unmanaged<TerminalView>.fromOpaque(viewPtr).takeUnretainedValue()

            // CONFIG_CHANGE is a notification that the config has already been
            // updated internally by libghostty. We do NOT call
            // ghostty_surface_update_config here — that would create an
            // infinite cycle since update_config fires CONFIG_CHANGE again.
            if rawAction.tag == GHOSTTY_ACTION_CONFIG_CHANGE {
                return true
            }

            // RELOAD_CONFIG on a surface: re-apply the current config so that
            // conditional state (e.g. light/dark theme) gets re-evaluated.
            // This is triggered by colorSchemeCallback → notifyConfigConditionalState.
            // Guard: ghostty_surface_update_config can re-fire actions that
            // call back into this handler, causing infinite recursion.
            if rawAction.tag == GHOSTTY_ACTION_RELOAD_CONFIG {
                guard !isUpdatingConfig else { return true }
                isUpdatingConfig = true
                defer { isUpdatingConfig = false }

                if let app = app,
                   let enginePtr = ghostty_app_userdata(app) {
                    let engine = Unmanaged<GhosttyEngine>.fromOpaque(enginePtr).takeUnretainedValue()
                    MainActor.assumeIsolated {
                        if let rawConfig = engine.config?.rawConfig {
                            ghostty_surface_update_config(surface, rawConfig)
                        }
                    }
                }
                return true
            }

            MainActor.assumeIsolated {
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
                 GHOSTTY_ACTION_SECURE_INPUT:
                return true
            default:
                break
            }
        }

        // Handle app-level reload_config by re-applying the existing config
        // so that conditional state (light/dark theme) gets re-evaluated.
        // Same recursion guard as the surface-level handler above.
        if target.tag == GHOSTTY_TARGET_APP,
           rawAction.tag == GHOSTTY_ACTION_RELOAD_CONFIG,
           let app = app,
           let enginePtr = ghostty_app_userdata(app) {
            guard !isUpdatingConfig else { return true }
            isUpdatingConfig = true
            defer { isUpdatingConfig = false }

            let engine = Unmanaged<GhosttyEngine>.fromOpaque(enginePtr).takeUnretainedValue()
            MainActor.assumeIsolated {
                if let rawConfig = engine.config?.rawConfig {
                    ghostty_app_update_config(app, rawConfig)
                }
            }
            return true
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

        // Copy the C string synchronously — the pointer is only valid during this callback.
        let entry = content.pointee
        guard let dataPtr = entry.data else { return }
        let str = String(cString: dataPtr)

        DispatchQueue.main.async {
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
