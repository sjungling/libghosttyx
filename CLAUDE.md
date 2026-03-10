# libghosttyx

Swift wrapper around [Ghostty](https://github.com/ghostty-org/ghostty)'s `libghostty` C library, providing a macOS terminal emulator component.

## Project Structure

```
Sources/libghosttyx/
  Core/           - GhosttyEngine, GhosttyConfig, GhosttySurface, GhosttyAction, etc.
  Views/          - TerminalView (NSView-based), LocalProcessTerminalView
  Extensions/     - NSEvent+Ghostty, NSPasteboard+Ghostty
  SwiftUI/        - TerminalViewRepresentable (SwiftUI wrapper)
Frameworks/       - Pre-built libghostty.xcframework (gitignored, must be built locally)
vendor/ghostty/   - Ghostty source as a git submodule
scripts/          - fetch-deps.sh, build-xcframework.sh
Examples/         - BasicTerminal (SPM), BasicTerminalApp (Xcode)
```

## Build Commands

```bash
# First time setup: fetch deps + build xcframework
./scripts/fetch-deps.sh
./scripts/build-xcframework.sh

# Build the Swift package
swift build

# Run tests
swift test
```

## Updating Ghostty

```bash
cd vendor/ghostty
git fetch origin
git checkout origin/main
cd ../..
# Then rebuild:
./scripts/build-xcframework.sh
swift build
```

## Prerequisites

- macOS 13+
- Xcode with Command Line Tools
- Zig (exact version in `.zig-version`, currently 0.15.2) - use `mise install zig` or download from ziglang.org

## Key Conventions

- The xcframework is NOT committed to git; it must be built locally
- `Package.swift` references the xcframework as a `.binaryTarget`
- The C library is imported via `import libghostty` in Swift files
- `TerminalView` is the primary public API surface (NSView subclass)
- macOS-only (`platforms: [.macOS(.v13)]`)
