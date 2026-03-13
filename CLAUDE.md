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
Makefile          - Build and clean targets (public interface)
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
```

Use `GHOSTTY_DIR=/path/to/ghostty` to build against an external Ghostty checkout instead of the vendored submodule.

## Releasing

Releases are triggered by pushing a version tag (`git tag v0.2.0 && git push origin v0.2.0`). The GitHub Actions workflow builds the xcframework, updates Package.swift with the download URL and checksum, and creates a GitHub release.

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

- **NEVER modify files under `vendor/ghostty/`** — this is a vendored git submodule. Changes to Ghostty must go upstream. Only modify our own Swift code in `Sources/libghosttyx/`.
- The xcframework is NOT committed to git; it must be built locally
- `Package.swift` has dual-mode resolution: uses local `Frameworks/libghostty.xcframework` if present, otherwise fetches from the GitHub Release URL (set by the release workflow)
- The C library is imported via `import libghostty` in Swift files
- `TerminalView` is the primary public API surface (NSView subclass)
- macOS-only (`platforms: [.macOS(.v13)]`)
