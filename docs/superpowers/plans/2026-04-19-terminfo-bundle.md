# Terminfo Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bundle the `xterm-ghostty` terminfo binary into the Swift package so embedded consumers automatically get `TERM=xterm-ghostty` instead of the `xterm-256color` fallback.

**Architecture:** Two resource files (`ghostty/.gitkeep` and `terminfo/78/xterm-ghostty`) are committed directly under `Sources/libghosttyx/` and declared as copied resources in `Package.swift`. Before `ghostty_init()`, `GhosttyEngine` sets `GHOSTTY_RESOURCES_DIR` via `setenv()` pointing to the bundled `ghostty/` directory; the C library then computes `TERMINFO = dirname(GHOSTTY_RESOURCES_DIR)/terminfo` which resolves to the sibling `terminfo/` directory.

**Tech Stack:** Swift 5.9, Swift Package Manager resources (`.copy`), Darwin `setenv`, libghostty C library

---

### Task 1: Commit resource files

**Files:**
- Create: `Sources/libghosttyx/ghostty/.gitkeep`
- Create: `Sources/libghosttyx/terminfo/78/xterm-ghostty`

- [ ] **Step 1: Create the ghostty placeholder directory**

```bash
mkdir -p Sources/libghosttyx/ghostty
touch Sources/libghosttyx/ghostty/.gitkeep
```

- [ ] **Step 2: Copy the terminfo binary from Ghostty.app**

```bash
mkdir -p Sources/libghosttyx/terminfo/78
cp /Applications/Ghostty.app/Contents/Resources/terminfo/78/xterm-ghostty \
   Sources/libghosttyx/terminfo/78/xterm-ghostty
```

- [ ] **Step 3: Verify the terminfo file is the right type**

```bash
file Sources/libghosttyx/terminfo/78/xterm-ghostty
```

Expected output: `Compiled terminfo entry "xterm-ghostty"`

---

### Task 2: Declare resources in Package.swift

**Files:**
- Modify: `Package.swift:44-59` (the `libghosttyx` target)

- [ ] **Step 1: Add resources array to the libghosttyx target**

Open `Package.swift`. The current target definition at line 44 is:

```swift
.target(
  name: "libghosttyx",
  dependencies: ["libghostty"],
  path: "Sources/libghosttyx",
  linkerSettings: [
    ...
  ]
),
```

Replace it with:

```swift
.target(
  name: "libghosttyx",
  dependencies: ["libghostty"],
  path: "Sources/libghosttyx",
  resources: [
    .copy("ghostty"),
    .copy("terminfo"),
  ],
  linkerSettings: [
    .linkedFramework("AppKit"),
    .linkedFramework("Carbon"),
    .linkedFramework("CoreGraphics"),
    .linkedFramework("CoreText"),
    .linkedFramework("Foundation"),
    .linkedFramework("IOSurface"),
    .linkedFramework("Metal"),
    .linkedFramework("QuartzCore"),
    .linkedLibrary("c++"),
    .linkedLibrary("z"),
  ]
),
```

`.copy` (not `.process`) preserves the binary terminfo file and directory structure without any build-system transformation.

- [ ] **Step 2: Verify the package resolves**

```bash
swift package dump-package 2>&1 | grep -A3 '"libghosttyx"'
```

Expected: no errors, shows the target with resources.

---

### Task 3: Write resource availability test

**Files:**
- Create: `Tests/libghosttyxTests/ResourceTests.swift`

- [ ] **Step 1: Create the test file**

```swift
import XCTest
@testable import libghosttyx

final class ResourceTests: XCTestCase {
    func testTerminfoFileExists() throws {
        let bundleURL = try XCTUnwrap(
            Bundle.module.resourceURL,
            "Bundle.module.resourceURL is nil — resources not declared in Package.swift"
        )
        let terminfo = bundleURL.appendingPathComponent("terminfo/78/xterm-ghostty")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: terminfo.path),
            "xterm-ghostty terminfo not found at \(terminfo.path)"
        )
    }

    func testGhosttyResourceDirectoryExists() throws {
        let bundleURL = try XCTUnwrap(Bundle.module.resourceURL)
        let ghosttyDir = bundleURL.appendingPathComponent("ghostty")
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: ghosttyDir.path, isDirectory: &isDir)
        XCTAssertTrue(exists && isDir.boolValue, "ghostty dir not found at \(ghosttyDir.path)")
    }
}
```

- [ ] **Step 2: Run the tests**

```bash
swift test --filter ResourceTests 2>&1 | tail -20
```

Expected:
```
Test Suite 'ResourceTests' passed at ...
     Executed 2 tests, with 0 failures
```

---

### Task 4: Set GHOSTTY_RESOURCES_DIR in GhosttyEngine

**Files:**
- Modify: `Sources/libghosttyx/Core/GhosttyEngine.swift:66`

The `initialize()` method currently calls `ghostty_init(0, nil)` at line 66. The C library reads `GHOSTTY_RESOURCES_DIR` during this call to populate its global `resources_dir`. It must be set before `ghostty_init()`.

- [ ] **Step 1: Insert the setenv call**

Open `Sources/libghosttyx/Core/GhosttyEngine.swift`. Find this block (around line 62):

```swift
public func initialize(config termConfig: TerminalConfiguration = .init()) throws {
    guard app == nil else { throw GhosttyError.alreadyInitialized }

    // Initialize the ghostty runtime
    let initResult = ghostty_init(0, nil)
```

Replace with:

```swift
public func initialize(config termConfig: TerminalConfiguration = .init()) throws {
    guard app == nil else { throw GhosttyError.alreadyInitialized }

    // Set GHOSTTY_RESOURCES_DIR before ghostty_init so the C library finds our
    // bundled terminfo and sets TERM=xterm-ghostty instead of xterm-256color.
    // The 0 flag means "don't overwrite" — embedders who set this themselves keep control.
    if let bundleURL = Bundle.module.resourceURL {
        setenv("GHOSTTY_RESOURCES_DIR", bundleURL.appendingPathComponent("ghostty").path, 0)
    }

    // Initialize the ghostty runtime
    let initResult = ghostty_init(0, nil)
```

- [ ] **Step 2: Build to verify no compile errors**

```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`

---

### Task 5: Run full test suite and commit

- [ ] **Step 1: Run the full test suite**

```bash
swift test 2>&1 | tail -20
```

Expected: all tests pass.

- [ ] **Step 2: Stage and commit**

```bash
git add Sources/libghosttyx/ghostty/.gitkeep \
        Sources/libghosttyx/terminfo/78/xterm-ghostty \
        Package.swift \
        Sources/libghosttyx/Core/GhosttyEngine.swift \
        Tests/libghosttyxTests/ResourceTests.swift
git commit -m "$(cat <<'EOF'
fix: bundle xterm-ghostty terminfo to fix TERM fallback in embedded mode

Sets GHOSTTY_RESOURCES_DIR before ghostty_init() using a bundled terminfo
so the C library picks xterm-ghostty instead of xterm-256color when there
is no app bundle to discover. Closes #7.
EOF
)"
```

- [ ] **Step 3: Manual verification (in an embedder like cortina)**

Open a terminal in the embedder. Run:

```bash
echo $TERM
```

Expected: `xterm-ghostty`

```bash
infocmp $TERM 2>&1 | head -3
```

Expected: first line shows `xterm-ghostty|...` with no errors.
