# Design: Bundle xterm-ghostty terminfo to fix TERM fallback in embedded mode

**Issue:** [#7](https://github.com/sjungling/libghosttyx/issues/7)  
**Date:** 2026-04-19  
**Status:** Approved

## Problem

When libghosttyx is used as an embedded terminal (not inside Ghostty.app), the C library (`libghostty`) always sets `TERM=xterm-256color` because `resources_dir` is nil. This happens unconditionally in `vendor/ghostty/src/termio/Exec.zig`:

```zig
if (cfg.resources_dir) |base| {
    try env.put("TERM", cfg.term);    // xterm-ghostty — never reached in embedded mode
    try env.put("TERMINFO", dir);
} else {
    try env.put("TERM", "xterm-256color"); // always fires
}
```

The C library discovers `resources_dir` at init time by walking up the binary's directory tree looking for `Contents/Resources/terminfo/78/xterm-ghostty` (macOS app bundle structure). Since embedded consumers have no `.app` bundle, the walk finds nothing.

**Impact:** Programs like tmux consult the `TERM` + terminfo database to decide what features to advertise. With `xterm-256color`, OSC 8 hyperlinks are absent from the terminfo entry, so tmux strips hyperlink sequences — even though Ghostty can render them.

Setting `TERM` via `TerminalConfiguration.environmentVariables` does not help: Exec.zig overwrites it unconditionally.

## Solution

### Mechanism

`vendor/ghostty/src/os/resourcesdir.zig` checks the `GHOSTTY_RESOURCES_DIR` environment variable in release builds **before** the directory walk:

```zig
if (comptime builtin.mode != .Debug) {
    if (std.process.getEnvVarOwned(alloc, "GHOSTTY_RESOURCES_DIR")) |dir| {
        if (dir.len > 0) return .{ .app_path = dir };
    }
}
```

Setting this env var in the host process before `ghostty_init()` causes the C library to treat it as the resources directory, making `cfg.resources_dir` non-nil, which causes Exec.zig to take the `TERM=xterm-ghostty` path.

### Approach: Auto-bundle + auto-set (no embedder changes required)

1. Commit the `xterm-ghostty` terminfo binary to the repo as a Swift Package resource.
2. In `GhosttyEngine.initialize()`, set `GHOSTTY_RESOURCES_DIR` via `setenv()` before `ghostty_init()`.

## File Layout

```
Sources/libghosttyx/Resources/
  ghostty/
    .gitkeep          ← GHOSTTY_RESOURCES_DIR points to this directory
  terminfo/
    78/
      xterm-ghostty   ← compiled terminfo binary, committed to git
```

The `ghostty/` and `terminfo/` directories must be siblings because the C library computes:

```zig
TERMINFO = dirname(GHOSTTY_RESOURCES_DIR) + "/terminfo"
```

So `GHOSTTY_RESOURCES_DIR = <bundle>/ghostty` → `TERMINFO = <bundle>/terminfo`.

The terminfo file is sourced from `vendor/ghostty/zig-out/share/ghostty/terminfo/78/xterm-ghostty` after an `make xcframework` build, or from an installed `Ghostty.app/Contents/Resources/terminfo/78/xterm-ghostty`. Since this is macOS-only and the file rarely changes between Ghostty versions, committing the compiled binary is appropriate.

## Package.swift Change

Add to the `libghosttyx` target's `resources` array:

```swift
.copy("Resources")
```

`.copy` (not `.process`) preserves the binary terminfo file without transformation.

## GhosttyEngine Change

In `GhosttyEngine.initialize()` (`Sources/libghosttyx/Core/GhosttyEngine.swift`), insert before `ghostty_init(0, nil)`:

```swift
if let resourcesURL = Bundle.module.resourceURL {
    setenv("GHOSTTY_RESOURCES_DIR", resourcesURL.appendingPathComponent("ghostty").path, 0)
}
```

The `0` flag on `setenv` means "don't overwrite if already set" — embedders who set `GHOSTTY_RESOURCES_DIR` themselves retain control.

`Bundle.module` is the SPM-generated accessor that resolves correctly for both local builds and consumers fetching the package from a GitHub Release.

## Constraints

- Only takes effect with release-mode xcframework builds (the `GHOSTTY_RESOURCES_DIR` check in `resourcesdir.zig` is gated on `builtin.mode != .Debug`). The shipped xcframework is always release-mode, so this is fine.
- `setenv()` mutates the process-wide environment. The env var is Ghostty-internal (`GHOSTTY_RESOURCES_DIR`) and the no-overwrite flag makes this safe.
- No embedder changes required — libghosttyx becomes self-sufficient.

## Files to Create/Modify

| File | Change |
|------|--------|
| `Sources/libghosttyx/Resources/ghostty/.gitkeep` | New (empty) |
| `Sources/libghosttyx/Resources/terminfo/78/xterm-ghostty` | New (committed binary) |
| `Package.swift` | Add `.copy("Resources")` to libghosttyx target |
| `Sources/libghosttyx/Core/GhosttyEngine.swift` | Set `GHOSTTY_RESOURCES_DIR` before `ghostty_init()` |

## Testing

- Build the Swift package: `swift build`
- Run in an embedder (e.g. cortina), open a shell, run `echo $TERM` — should output `xterm-ghostty`
- Run `infocmp $TERM` — should resolve without error
- Inside tmux, verify `echo $TERM` still shows `xterm-ghostty` (or the tmux outer-TERM value is correctly set)
