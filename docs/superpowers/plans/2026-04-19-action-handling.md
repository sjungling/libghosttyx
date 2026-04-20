# Action Handling Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix six action types that `GhosttyCallbackBridge` claims as handled but `TerminalView.handleAction` silently discards, by adding delegate callbacks, built-in `NSCursor` behavior for mouse visibility, and a `#if DEBUG` log for future gaps.

**Architecture:** Each action gets a new `TerminalViewDelegate` protocol method (with a no-op default so existing host apps don't break) and a matching `case` branch in `handleAction`. `mouseVisibility` additionally calls `NSCursor.hide()`/`unhide()` directly in `TerminalView` before firing the delegate, matching the existing pattern for `mouseShape`/`updateCursor`. The bridge requires no changes.

**Tech Stack:** Swift, AppKit (`NSCursor`), `os` framework (`os_log`), XCTest

---

## File Map

| File | Action |
|------|--------|
| `Sources/libghosttyx/Views/TerminalViewDelegate.swift` | Add 6 protocol methods + 6 default no-op implementations |
| `Sources/libghosttyx/Views/TerminalView.swift` | Add `import os`, 6 `case` branches in `handleAction`, `#if DEBUG` log in `default` |
| `Tests/libghosttyxTests/ActionHandlingTests.swift` | Create — `MockDelegate` + 8 XCTest methods |

---

## Task 1: Add delegate protocol methods and write failing tests

**Files:**
- Modify: `Sources/libghosttyx/Views/TerminalViewDelegate.swift`
- Create: `Tests/libghosttyxTests/ActionHandlingTests.swift`

- [ ] **Step 1: Add 6 methods to the `TerminalViewDelegate` protocol**

Open `Sources/libghosttyx/Views/TerminalViewDelegate.swift`. Add these six declarations inside the `public protocol TerminalViewDelegate: AnyObject` block, after the existing `colorChanged` declaration on line 50:

```swift
    /// Called when the terminal requests the mouse cursor be shown or hidden.
    func mouseVisibilityChanged(source: TerminalView, visible: Bool)

    /// Called when secure input mode changes (e.g. a password prompt via sudo).
    func secureInputChanged(source: TerminalView, enabled: Bool)

    /// Called when Ghostty sets size constraints for the terminal.
    func sizeLimitChanged(source: TerminalView, minCols: UInt32, minRows: UInt32, maxCols: UInt32, maxRows: UInt32)

    /// Called when Ghostty requests an initial terminal size.
    func initialSizeRequested(source: TerminalView, cols: UInt32, rows: UInt32)

    /// Called when a foreground command reports progress.
    func progressReported(source: TerminalView, state: ghostty_action_progress_report_state_e, progress: Int8)

    /// Called when the GPU renderer health changes.
    func rendererHealthChanged(source: TerminalView, health: ghostty_action_renderer_health_e)
```

- [ ] **Step 2: Add 6 no-op default implementations**

In the same file, add these to the `public extension TerminalViewDelegate` block at the bottom, after the existing `colorChanged` default:

```swift
    func mouseVisibilityChanged(source: TerminalView, visible: Bool) {}
    func secureInputChanged(source: TerminalView, enabled: Bool) {}
    func sizeLimitChanged(source: TerminalView, minCols: UInt32, minRows: UInt32, maxCols: UInt32, maxRows: UInt32) {}
    func initialSizeRequested(source: TerminalView, cols: UInt32, rows: UInt32) {}
    func progressReported(source: TerminalView, state: ghostty_action_progress_report_state_e, progress: Int8) {}
    func rendererHealthChanged(source: TerminalView, health: ghostty_action_renderer_health_e) {}
```

- [ ] **Step 3: Verify the delegate file compiles**

```bash
swift build 2>&1 | grep -E "error:|warning:|Build complete"
```

Expected: `Build complete!` with no errors. If there are errors, fix them before continuing.

- [ ] **Step 4: Create the test file with the mock delegate and all 8 tests**

Create `Tests/libghosttyxTests/ActionHandlingTests.swift` with this content:

```swift
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
```

- [ ] **Step 5: Run tests to confirm failures**

```bash
swift test --filter ActionHandlingTests 2>&1 | tail -20
```

Expected: All 8 tests **fail** because `handleAction` doesn't call the delegate methods yet. You should see output like:
```
Test Case 'ActionHandlingTests.testMouseVisibilityHideNotifiesDelegate' failed
XCTAssertEqual failed: ("nil") is not equal to ("Optional(false)")
```

If instead you see compile errors, fix them before continuing.

- [ ] **Step 6: Commit the failing tests and delegate protocol**

```bash
git add Sources/libghosttyx/Views/TerminalViewDelegate.swift Tests/libghosttyxTests/ActionHandlingTests.swift
git commit -m "test(actions): add failing tests for 6 unhandled action types"
```

---

## Task 2: Implement the `handleAction` cases and debug logging

**Files:**
- Modify: `Sources/libghosttyx/Views/TerminalView.swift`

- [ ] **Step 1: Add `import os` to TerminalView.swift**

Open `Sources/libghosttyx/Views/TerminalView.swift`. The file currently starts with:

```swift
import AppKit
import libghostty
```

Change it to:

```swift
import AppKit
import libghostty
import os
```

- [ ] **Step 2: Add the 6 case branches to `handleAction`**

In `TerminalView.swift`, find the `handleAction` method. It currently ends with:

```swift
    case .mouseOverLink(let url):
      currentHoverLink = url
      delegate?.mouseOverLink(source: self, url: url)

    default:
      break
    }
  }
```

Replace that entire closing section with:

```swift
    case .mouseOverLink(let url):
      currentHoverLink = url
      delegate?.mouseOverLink(source: self, url: url)

    case .mouseVisibility(let visibility):
      let visible = visibility == GHOSTTY_MOUSE_VISIBLE
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
    }
  }
```

- [ ] **Step 3: Run tests to confirm all 8 pass**

```bash
swift test --filter ActionHandlingTests 2>&1 | tail -20
```

Expected output:
```
Test Suite 'ActionHandlingTests' passed
Executed 8 tests, with 0 failures (0 unexpected) in X.XXX seconds
```

If any tests fail, read the failure message carefully — it will tell you which assertion failed and with what value. Fix the corresponding `case` branch and re-run.

- [ ] **Step 4: Run the full test suite to confirm no regressions**

```bash
swift test 2>&1 | tail -10
```

Expected: All tests pass with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/libghosttyx/Views/TerminalView.swift
git commit -m "feat(actions): handle mouseVisibility, secureInput, sizeLimit, initialSize, progressReport, rendererHealth"
```
