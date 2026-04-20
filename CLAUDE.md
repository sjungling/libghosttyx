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

Releases are triggered **manually** via `workflow_dispatch`, not by pushing a tag. From the GitHub Actions UI (or `gh workflow run release.yml -f version=v0.3.18`), the workflow:

1. Validates the version string and that the tag doesn't already exist
2. Builds the xcframework from `main` and computes its SHA-256
3. Rewrites `Package.swift` via sed anchored on the trailing `// libghosttyx-url` and `// libghosttyx-checksum` comments
4. Commits `chore: release $TAG` to `main`, creates the tag **on that commit**, pushes both
5. Creates the GitHub Release and uploads the xcframework zip
6. Downloads the published asset back and asserts its SHA matches both the computed checksum and what's in `Package.swift` — the build fails loudly if anything drifts

### Release rules (invariants)

- **NEVER force-push tags.** Tags must point at the release commit from creation. The workflow creates the tag *after* the Package.swift update is committed; it never moves an existing tag. If a release needs to be redone, bump the patch version instead of retagging.
- **NEVER hand-edit `xcframeworkURL` or `xcframeworkChecksum` in `Package.swift`.** CI owns those lines. The trailing `// libghosttyx-url` / `// libghosttyx-checksum` anchors must stay on the same line as their values — the release workflow's sed substitution finds them by those anchors.
- **`Package.swift` carries `// swift-format-ignore-file`** to prevent formatters from rewrapping the anchor lines. Do not remove that directive.
- **Broken releases stay broken.** If a published release's `Package.swift` and asset disagree, do not attempt to fix the existing tag — tag a new patch version.

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
