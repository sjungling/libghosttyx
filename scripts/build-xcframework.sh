#!/usr/bin/env bash
#
# Builds libghostty.xcframework from the Ghostty source.
#
# Usage:
#   ./scripts/build-xcframework.sh [path-to-ghostty-repo]
#
# If no path is provided, uses the vendor/ghostty submodule.
# The resulting xcframework is placed at Frameworks/libghostty.xcframework/
#
# Prerequisites:
#   - Xcode with Command Line Tools
#   - Zig (exact version must match .zig-version)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/Frameworks"
XCFRAMEWORK_PATH="$OUTPUT_DIR/libghostty.xcframework"
ZIG_VERSION_FILE="$PROJECT_ROOT/.zig-version"

# --- Zig version check ---
if [[ ! -f "$ZIG_VERSION_FILE" ]]; then
    echo "Error: .zig-version file not found at $ZIG_VERSION_FILE"
    exit 1
fi

EXPECTED_ZIG_VERSION="$(tr -d '[:space:]' < "$ZIG_VERSION_FILE")"

if ! command -v zig &>/dev/null; then
    echo "Error: zig not found in PATH."
    echo "Required version: $EXPECTED_ZIG_VERSION"
    echo "Install from https://ziglang.org/download/ or use mise: mise install zig"
    exit 1
fi

ACTUAL_ZIG_VERSION="$(zig version)"
if [[ "$ACTUAL_ZIG_VERSION" != "$EXPECTED_ZIG_VERSION" ]]; then
    echo "Error: Zig version mismatch."
    echo "  Expected: $EXPECTED_ZIG_VERSION (from .zig-version)"
    echo "  Actual:   $ACTUAL_ZIG_VERSION"
    exit 1
fi

echo "Zig version OK: $ACTUAL_ZIG_VERSION"

# --- Ghostty source ---
if [[ $# -ge 1 ]]; then
    GHOSTTY_DIR="$1"
    if [[ ! -d "$GHOSTTY_DIR" ]]; then
        echo "Error: Ghostty directory not found: $GHOSTTY_DIR"
        exit 1
    fi
    echo "Using Ghostty checkout: $GHOSTTY_DIR"
else
    GHOSTTY_DIR="$PROJECT_ROOT/vendor/ghostty"

    # Auto-fetch if submodule isn't initialized
    if [[ ! -f "$GHOSTTY_DIR/build.zig" ]]; then
        echo "Ghostty submodule not initialized — running fetch-deps.sh..."
        "$SCRIPT_DIR/fetch-deps.sh"
    fi

    if [[ ! -f "$GHOSTTY_DIR/build.zig" ]]; then
        echo "Error: build.zig not found in $GHOSTTY_DIR"
        echo "Run ./scripts/fetch-deps.sh first, or pass a Ghostty path."
        exit 1
    fi
    echo "Using vendor/ghostty submodule"
fi

# --- Build ---
echo "Building libghostty (universal) with zig $ACTUAL_ZIG_VERSION..."
cd "$GHOSTTY_DIR"

zig build --release=fast -Dapp-runtime=none -Demit-xcframework=true \
    -Dxcframework-target=universal -Demit-macos-app=false

BUILT_XCFRAMEWORK="$GHOSTTY_DIR/macos/GhosttyKit.xcframework"

if [[ ! -d "$BUILT_XCFRAMEWORK" ]]; then
    echo "Error: xcframework not found at $BUILT_XCFRAMEWORK"
    exit 1
fi

# --- Copy xcframework ---
rm -rf "$XCFRAMEWORK_PATH"
mkdir -p "$OUTPUT_DIR"
cp -R "$BUILT_XCFRAMEWORK" "$XCFRAMEWORK_PATH"

# --- Strip iOS slices (this package is macOS-only) ---
for slice_dir in "$XCFRAMEWORK_PATH"/ios-*/; do
    if [[ -d "$slice_dir" ]]; then
        echo "Removing iOS slice: $(basename "$slice_dir")"
        rm -rf "$slice_dir"
    fi
done

# --- Rename library ---
# Universal build produces libghostty.a, native produces libghostty-fat.a.
# Normalize to libghostty.a in all cases.
for arch_dir in "$XCFRAMEWORK_PATH"/macos-*/; do
    if [[ -f "$arch_dir/libghostty-fat.a" ]]; then
        mv "$arch_dir/libghostty-fat.a" "$arch_dir/libghostty.a"
    fi
    if [[ ! -f "$arch_dir/libghostty.a" ]]; then
        echo "Error: no static library found in $(basename "$arch_dir")"
        ls -la "$arch_dir"
        exit 1
    fi
done

# --- Rewrite module maps ---
for arch_dir in "$XCFRAMEWORK_PATH"/macos-*/; do
    if [[ -f "$arch_dir/Headers/module.modulemap" ]]; then
        cat > "$arch_dir/Headers/module.modulemap" << 'MODULEMAP'
module libghostty {
    umbrella header "ghostty.h"
    export *
}
MODULEMAP
    fi
done

# --- Generate Info.plist from remaining slices ---
# Parse directory names using the pattern: {platform}-{arch1}[_{arch2}...][-{variant}]
generate_plist() {
    cat << 'HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AvailableLibraries</key>
    <array>
HEADER

    for slice_dir in "$XCFRAMEWORK_PATH"/macos-*/; do
        [[ -d "$slice_dir" ]] || continue
        local dirname
        dirname="$(basename "$slice_dir")"

        # Extract platform and the rest: macos-arm64_x86_64 or macos-arm64-simulator
        local rest="${dirname#macos-}"
        local variant=""

        # Check for variant suffix (e.g., -simulator)
        if [[ "$rest" == *-* ]]; then
            # Could be arch_arch-variant or just arch-variant
            # Split on last hyphen that isn't part of arch names
            local arch_part="${rest%-*}"
            local maybe_variant="${rest##*-}"
            # If the part after last hyphen doesn't look like an arch, it's a variant
            if [[ "$maybe_variant" != "arm64" && "$maybe_variant" != "x86_64" && "$maybe_variant" != "arm64e" ]]; then
                variant="$maybe_variant"
                rest="$arch_part"
            fi
        fi

        # Split architectures on underscore, preserving x86_64 as atomic
        local normalized="${rest//x86_64/x86-64}"
        IFS='_' read -ra archs <<< "$normalized"
        archs=("${archs[@]//x86-64/x86_64}")

        cat << EOF
        <dict>
            <key>HeadersPath</key>
            <string>Headers</string>
            <key>LibraryIdentifier</key>
            <string>$dirname</string>
            <key>LibraryPath</key>
            <string>libghostty.a</string>
            <key>SupportedArchitectures</key>
            <array>
EOF
        for arch in "${archs[@]}"; do
            echo "                <string>$arch</string>"
        done

        cat << EOF
            </array>
            <key>SupportedPlatform</key>
            <string>macos</string>
EOF
        if [[ -n "$variant" ]]; then
            cat << EOF
            <key>SupportedPlatformVariant</key>
            <string>$variant</string>
EOF
        fi
        echo "        </dict>"
    done

    cat << 'FOOTER'
    </array>
    <key>CFBundlePackageType</key>
    <string>XFWK</string>
    <key>XCFrameworkFormatVersion</key>
    <string>1.0</string>
</dict>
</plist>
FOOTER
}

generate_plist > "$XCFRAMEWORK_PATH/Info.plist"

# --- Summary ---
echo ""
echo "Successfully built: $XCFRAMEWORK_PATH"
for arch_dir in "$XCFRAMEWORK_PATH"/macos-*/; do
    echo "  $(basename "$arch_dir"):"
    ls -lh "$arch_dir/libghostty.a" 2>/dev/null | awk '{print "    " $5 " " $9}'
    if command -v lipo &>/dev/null; then
        lipo -info "$arch_dir/libghostty.a" 2>/dev/null | sed 's/^/    /'
    fi
done
echo ""
echo "You can now build the Swift package with: swift build"
