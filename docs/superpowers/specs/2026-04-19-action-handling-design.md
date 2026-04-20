# Action Handling Fix — Design Spec

**Issue:** [#6 — Several action types claimed as handled but silently dropped](https://github.com/sjungling/libghosttyx/issues/6)
**Date:** 2026-04-19
**Branch:** light-bronze-charm

---

## Problem

`GhosttyCallbackBridge.actionCallback` returns `true` (handled) for six action types that `TerminalView.handleAction` silently discards via `default: break`. Ghostty believes these are handled; they are not.

**Affected actions:**
- `GHOSTTY_ACTION_MOUSE_VISIBILITY` — cursor show/hide on typing
- `GHOSTTY_ACTION_SECURE_INPUT` — password prompt mode
- `GHOSTTY_ACTION_SIZE_LIMIT` — min/max terminal size constraints
- `GHOSTTY_ACTION_INITIAL_SIZE` — preferred startup size
- `GHOSTTY_ACTION_PROGRESS_REPORT` — command progress indicator
- `GHOSTTY_ACTION_RENDERER_HEALTH` — GPU renderer status

`mouseVisibility` and `secureInput` have direct user-visible consequences. The rest affect host app behavior.

---

## Approach

**Approach C:** Handle all 6 with delegate callbacks + built-in behavior where appropriate + debug logging for future gaps.

- `TerminalView` handles `mouseVisibility` internally (calls `NSCursor.hide()`/`unhide()`) and fires the delegate, matching the existing pattern used by `mouseShape`/`updateCursor`.
- All 6 actions fire new delegate methods with no-op defaults so existing host apps are unaffected.
- `default: break` in `handleAction` gains a `#if DEBUG` `os_log` so future unhandled actions surface during development.
- `GhosttyCallbackBridge` requires no changes — the bridge already returns `true` for these actions, which is correct once they are genuinely handled.

---

## Design

### 1. `TerminalViewDelegate` — 6 new methods

All added to the protocol with no-op default implementations in the protocol extension. No breaking changes to existing adopters.

```swift
func mouseVisibilityChanged(source: TerminalView, visible: Bool)
func secureInputChanged(source: TerminalView, enabled: Bool)
func sizeLimitChanged(source: TerminalView, minCols: UInt32, minRows: UInt32, maxCols: UInt32, maxRows: UInt32)
func initialSizeRequested(source: TerminalView, cols: UInt32, rows: UInt32)
func progressReported(source: TerminalView, state: ghostty_action_progress_report_state_e, progress: Int8)
func rendererHealthChanged(source: TerminalView, health: ghostty_action_renderer_health_e)
```

### 2. `TerminalView.handleAction` — 6 new case branches

```swift
case .mouseVisibility(let visibility):
    let visible = visibility == GHOSTTY_MOUSE_VISIBILITY_VISIBLE
    if visible { NSCursor.unhide() } else { NSCursor.hide() }
    delegate?.mouseVisibilityChanged(source: self, visible: visible)

case .secureInput(let state):
    delegate?.secureInputChanged(source: self, enabled: state == GHOSTTY_SECURE_INPUT_ON)

case .sizeLimit(let minW, let minH, let maxW, let maxH):
    delegate?.sizeLimitChanged(source: self, minCols: minW, minRows: minH, maxCols: maxW, maxRows: maxH)

case .initialSize(let w, let h):
    delegate?.initialSizeRequested(source: self, cols: w, rows: h)

case .progressReport(let state, let progress):
    delegate?.progressReported(source: self, state: state, progress: progress)

case .rendererHealth(let health):
    delegate?.rendererHealthChanged(source: self, health: health)

default:
    #if DEBUG
    os_log(.debug, "TerminalView: unhandled action %{public}@", String(describing: action))
    #endif
    break
```

**Note on `NSCursor.hide()`:** This is a global push/pop balanced API. Ghostty manages the protocol and sends matching pairs — we translate the signal directly without tracking local state.

### 3. `GhosttyCallbackBridge` — no changes

The bridge already lists all 6 actions in its `return true` switch. Once `handleAction` actually handles them, the bridge is correct as-is.

### 4. Tests — `ActionHandlingTests.swift`

New file at `Tests/libghosttyxTests/ActionHandlingTests.swift`.

Uses `@testable import libghosttyx` (same as existing tests) to access `internal` `handleAction`. A `MockDelegate` class records which callbacks fired and their argument values.

Tests:
- `testMouseVisibilityHideNotifiesDelegate`
- `testMouseVisibilityShowNotifiesDelegate`
- `testSecureInputOnNotifiesDelegate`
- `testSecureInputOffNotifiesDelegate`
- `testSizeLimitNotifiesDelegate`
- `testInitialSizeNotifiesDelegate`
- `testProgressReportNotifiesDelegate`
- `testRendererHealthNotifiesDelegate`

AppKit side effects (`NSCursor.hide()`) are not tested — they require a real display and follow the same deliberately-avoided pattern as the rest of the test suite.

---

## File Summary

| File | Change |
|------|--------|
| `Sources/libghosttyx/Views/TerminalViewDelegate.swift` | Add 6 delegate methods + default no-ops |
| `Sources/libghosttyx/Views/TerminalView.swift` | Add 6 `case` branches + `#if DEBUG` log in `default` |
| `Sources/libghosttyx/Core/GhosttyCallbackBridge.swift` | No changes |
| `Tests/libghosttyxTests/ActionHandlingTests.swift` | New file, 8 tests |

---

## Non-Goals

- Window-level enforcement of `sizeLimit` — delegated to host app, not implemented in `TerminalView`
- Dock progress bar for `progressReport` — delegated to host app
- Persistent `isSecureInput` state property on `TerminalView` — not needed; delegate fires on change
