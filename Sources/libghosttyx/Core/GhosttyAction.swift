import Foundation
import libghostty

/// Swift-friendly representation of ghostty action payloads.
///
/// These are extracted from the raw `ghostty_action_s` union and presented
/// as associated values for type-safe consumption by delegates.
public enum GhosttyAction {
    case setTitle(String)
    case bell
    case cellSize(width: UInt32, height: UInt32)
    case scrollbar(total: UInt64, offset: UInt64, length: UInt64)
    case workingDirectory(String)
    case mouseShape(ghostty_action_mouse_shape_e)
    case mouseVisibility(ghostty_action_mouse_visibility_e)
    case render
    case colorChange(kind: ghostty_action_color_kind_e, r: UInt8, g: UInt8, b: UInt8)
    case openURL(String)
    case reloadConfig(soft: Bool)
    case sizeLimit(minWidth: UInt32, minHeight: UInt32, maxWidth: UInt32, maxHeight: UInt32)
    case initialSize(width: UInt32, height: UInt32)
    case desktopNotification(title: String, body: String)
    case mouseOverLink(String?)
    case rendererHealth(ghostty_action_renderer_health_e)
    case showChildExited(exitCode: UInt32, runtimeMs: UInt64)
    case progressReport(state: ghostty_action_progress_report_state_e, progress: Int8)
    case secureInput(ghostty_action_secure_input_e)

    // App-level actions (not routed to individual surfaces)
    case quit
    case newWindow
    case newTab
    case closeTab
    case newSplit(ghostty_action_split_direction_e)
    case toggleFullscreen
    case toggleMaximize
    case closeAllWindows
    case closeWindow
    case openConfig
    case checkForUpdates

    /// Other/unhandled action
    case other(ghostty_action_tag_e)

    /// Creates a `GhosttyAction` from a raw ghostty action struct.
    static func from(_ raw: ghostty_action_s) -> GhosttyAction {
        switch raw.tag {
        case GHOSTTY_ACTION_SET_TITLE:
            let title = raw.action.set_title.title.map { String(cString: $0) } ?? ""
            return .setTitle(title)

        case GHOSTTY_ACTION_RING_BELL:
            return .bell

        case GHOSTTY_ACTION_CELL_SIZE:
            let cs = raw.action.cell_size
            return .cellSize(width: cs.width, height: cs.height)

        case GHOSTTY_ACTION_SCROLLBAR:
            let sb = raw.action.scrollbar
            return .scrollbar(total: sb.total, offset: sb.offset, length: sb.len)

        case GHOSTTY_ACTION_PWD:
            let pwd = raw.action.pwd.pwd.map { String(cString: $0) } ?? ""
            return .workingDirectory(pwd)

        case GHOSTTY_ACTION_MOUSE_SHAPE:
            return .mouseShape(raw.action.mouse_shape)

        case GHOSTTY_ACTION_MOUSE_VISIBILITY:
            return .mouseVisibility(raw.action.mouse_visibility)

        case GHOSTTY_ACTION_RENDER:
            return .render

        case GHOSTTY_ACTION_COLOR_CHANGE:
            let cc = raw.action.color_change
            return .colorChange(kind: cc.kind, r: cc.r, g: cc.g, b: cc.b)

        case GHOSTTY_ACTION_OPEN_URL:
            let url = raw.action.open_url
            if let ptr = url.url {
                let str = String(cString: ptr)
                return .openURL(str)
            }
            return .openURL("")

        case GHOSTTY_ACTION_RELOAD_CONFIG:
            return .reloadConfig(soft: raw.action.reload_config.soft)

        case GHOSTTY_ACTION_SIZE_LIMIT:
            let sl = raw.action.size_limit
            return .sizeLimit(
                minWidth: sl.min_width, minHeight: sl.min_height,
                maxWidth: sl.max_width, maxHeight: sl.max_height
            )

        case GHOSTTY_ACTION_INITIAL_SIZE:
            let s = raw.action.initial_size
            return .initialSize(width: s.width, height: s.height)

        case GHOSTTY_ACTION_DESKTOP_NOTIFICATION:
            let dn = raw.action.desktop_notification
            let title = dn.title.map { String(cString: $0) } ?? ""
            let body = dn.body.map { String(cString: $0) } ?? ""
            return .desktopNotification(title: title, body: body)

        case GHOSTTY_ACTION_MOUSE_OVER_LINK:
            let mol = raw.action.mouse_over_link
            if let ptr = mol.url, mol.len > 0 {
                return .mouseOverLink(String(cString: ptr))
            }
            return .mouseOverLink(nil)

        case GHOSTTY_ACTION_RENDERER_HEALTH:
            return .rendererHealth(raw.action.renderer_health)

        case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
            let ce = raw.action.child_exited
            return .showChildExited(exitCode: ce.exit_code, runtimeMs: ce.timetime_ms)

        case GHOSTTY_ACTION_PROGRESS_REPORT:
            let pr = raw.action.progress_report
            return .progressReport(state: pr.state, progress: pr.progress)

        case GHOSTTY_ACTION_SECURE_INPUT:
            return .secureInput(raw.action.secure_input)

        case GHOSTTY_ACTION_QUIT:
            return .quit

        case GHOSTTY_ACTION_NEW_WINDOW:
            return .newWindow

        case GHOSTTY_ACTION_NEW_TAB:
            return .newTab

        case GHOSTTY_ACTION_CLOSE_TAB:
            return .closeTab

        case GHOSTTY_ACTION_NEW_SPLIT:
            return .newSplit(raw.action.new_split)

        case GHOSTTY_ACTION_TOGGLE_FULLSCREEN:
            return .toggleFullscreen

        case GHOSTTY_ACTION_TOGGLE_MAXIMIZE:
            return .toggleMaximize

        case GHOSTTY_ACTION_CLOSE_ALL_WINDOWS:
            return .closeAllWindows

        case GHOSTTY_ACTION_CLOSE_WINDOW:
            return .closeWindow

        case GHOSTTY_ACTION_OPEN_CONFIG:
            return .openConfig

        case GHOSTTY_ACTION_CHECK_FOR_UPDATES:
            return .checkForUpdates

        default:
            return .other(raw.tag)
        }
    }

    /// Whether this is an app-level action (not targeted at a specific surface).
    public var isAppLevel: Bool {
        switch self {
        case .quit, .newWindow, .newTab, .closeTab, .newSplit,
             .toggleFullscreen, .toggleMaximize, .closeAllWindows,
             .closeWindow, .openConfig, .checkForUpdates:
            return true
        default:
            return false
        }
    }
}
