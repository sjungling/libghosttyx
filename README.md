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
make build
```

This initializes the Ghostty submodule, prefetches Zig build dependencies, and builds `Frameworks/libghostty.xcframework/` containing a universal (arm64 + x86_64) static library.

You can also run the steps individually:

```bash
make fetch-deps   # Initialize submodule + prefetch Zig deps
make xcframework   # Build libghostty.xcframework
```

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
make xcframework
swift build
```

To pin to a specific version:

```bash
cd vendor/ghostty
git fetch origin --tags
git checkout v1.3.0  # or any tag/commit
cd ../..
make xcframework
```

After updating, verify the Swift package still compiles with `swift build`.

## Make Targets

| Target | Description |
|--------|-------------|
| `make build` | Fetch deps + build xcframework (full setup) |
| `make fetch-deps` | Initialize submodule and prefetch Zig build dependencies |
| `make xcframework` | Build the universal xcframework from Ghostty source |
| `make clean` | Remove built xcframework and zip artifacts |
| `make release` | Auto-detect version bump, build, tag, and publish a release |
| `make release BUMP=minor` | Force a specific version bump (major, minor, patch) |

## Project Structure

```
Package.swift             # Swift package manifest (macOS 13+)
Makefile                  # Build, clean, and release targets
Sources/libghosttyx/
  Core/                   # Engine, config, surface, input handling
  Views/                  # TerminalView (NSView), LocalProcessTerminalView
  Extensions/             # NSEvent, NSPasteboard helpers
  SwiftUI/                # TerminalViewRepresentable
Frameworks/               # Built xcframework (not committed to git)
vendor/ghostty/           # Ghostty source (git submodule)
Examples/
  BasicTerminal/          # Minimal SPM-based example
  BasicTerminalApp/       # Xcode app example
```

## Troubleshooting

**Zig version mismatch**: The build enforces the exact Zig version in `.zig-version`. Install the correct version with `mise install zig` or download it directly.

**Missing xcframework**: The `Frameworks/` directory is gitignored. Run `make build` after cloning.

**Submodule not initialized**: Run `git submodule update --init --recursive` or `make fetch-deps`.
