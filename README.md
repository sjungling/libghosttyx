# libghosttyx

A Swift package that wraps [Ghostty](https://github.com/ghostty-org/ghostty)'s terminal emulator library (`libghostty`) for macOS, providing an embeddable terminal view for Swift and SwiftUI applications.

## Prerequisites

- **macOS 13+**
- **Xcode** with Command Line Tools
- **Zig** (exact version specified in `.zig-version`) - install via [mise](https://mise.jdx.dev/) (`mise install zig`) or from [ziglang.org](https://ziglang.org/download/)

## Quick Start

### 1. Clone the repository

```bash
git clone --recursive <repo-url>
cd libghosttyx
```

If you already cloned without `--recursive`:

```bash
git submodule update --init --recursive
```

### 2. Build the xcframework

```bash
./scripts/fetch-deps.sh        # Initialize submodule + prefetch Zig deps
./scripts/build-xcframework.sh  # Build libghostty.xcframework (universal binary)
```

This produces `Frameworks/libghostty.xcframework/` containing a universal (arm64 + x86_64) static library.

### 3. Build the Swift package

```bash
swift build
```

## Usage

### SwiftUI

```swift
import libghosttyx

struct ContentView: View {
    var body: some View {
        TerminalViewRepresentable()
    }
}
```

### AppKit

```swift
import libghosttyx

let terminalView = TerminalView()
// Configure and add to your view hierarchy
```

See the `Examples/` directory for complete working apps.

## Updating Ghostty Sources

To update to the latest Ghostty:

```bash
cd vendor/ghostty
git fetch origin
git checkout origin/main
cd ../..
./scripts/build-xcframework.sh
swift build
```

To pin to a specific version:

```bash
cd vendor/ghostty
git fetch origin --tags
git checkout v1.3.0  # or any tag/commit
cd ../..
./scripts/build-xcframework.sh
```

After updating, verify the Swift package still compiles with `swift build`.

## Project Structure

```
Package.swift             # Swift package manifest (macOS 13+)
Sources/libghosttyx/
  Core/                   # Engine, config, surface, input handling
  Views/                  # TerminalView (NSView), LocalProcessTerminalView
  Extensions/             # NSEvent, NSPasteboard helpers
  SwiftUI/                # TerminalViewRepresentable
Frameworks/               # Built xcframework (not committed to git)
vendor/ghostty/           # Ghostty source (git submodule)
scripts/
  fetch-deps.sh           # Initialize submodule + prefetch Zig build deps
  build-xcframework.sh    # Build universal xcframework from Ghostty source
Examples/
  BasicTerminal/          # Minimal SPM-based example
  BasicTerminalApp/       # Xcode app example
```

## Troubleshooting

**Zig version mismatch**: The build scripts enforce the exact Zig version in `.zig-version`. Install the correct version with `mise install zig` or download it directly.

**Missing xcframework**: The `Frameworks/` directory is gitignored. Run `./scripts/build-xcframework.sh` after cloning.

**Submodule not initialized**: Run `git submodule update --init --recursive` or `./scripts/fetch-deps.sh`.
