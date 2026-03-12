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
Makefile          - Build, clean, and release targets (public interface)
scripts/          - fetch-deps.sh, build-xcframework.sh (implementation details)
Examples/         - BasicTerminal (SPM), BasicTerminalApp (Xcode)
```

## Build Commands

```bash
# First time setup: fetch deps + build xcframework
make build

# Or run steps individually
make fetch-deps    # Initialize submodule + prefetch Zig deps
make xcframework   # Build universal xcframework

# Build the Swift package
swift build

# Run tests
swift test

# Clean built artifacts
make clean

# Cut a release (auto-detects semver bump from conventional commits)
make release
make release BUMP=minor  # Force a specific bump
```

Use `GHOSTTY_DIR=/path/to/ghostty` to build against an external Ghostty checkout instead of the vendored submodule.

## Updating Ghostty

```bash
cd vendor/ghostty
git fetch origin
git checkout origin/main
cd ../..
# Then rebuild:
make xcframework
swift build
```

## Prerequisites

- macOS 13+
- Xcode with Command Line Tools
- Zig (exact version in `.zig-version`, currently 0.15.2) - use `mise install zig` or download from ziglang.org

## Key Conventions

- The xcframework is NOT committed to git; it must be built locally
- `Package.swift` has dual-mode resolution: uses local `Frameworks/libghostty.xcframework` if present, otherwise fetches from the GitHub Release URL (set during `make release`)
- The C library is imported via `import libghostty` in Swift files
- `TerminalView` is the primary public API surface (NSView subclass)
- macOS-only (`platforms: [.macOS(.v13)]`)
