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
#   - Zig (the version Ghostty requires — check Ghostty's README)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/Frameworks"
XCFRAMEWORK_PATH="$OUTPUT_DIR/libghostty.xcframework"

# Use provided path, or fall back to vendor/ghostty submodule
if [[ $# -ge 1 ]]; then
    GHOSTTY_DIR="$1"
    if [[ ! -d "$GHOSTTY_DIR" ]]; then
        echo "Error: Ghostty directory not found: $GHOSTTY_DIR"
        exit 1
    fi
    echo "Using Ghostty checkout: $GHOSTTY_DIR"
elif [[ -d "$PROJECT_ROOT/vendor/ghostty" ]]; then
    GHOSTTY_DIR="$PROJECT_ROOT/vendor/ghostty"
    echo "Using vendor/ghostty submodule"

    # Initialize submodule if needed
    if [[ ! -f "$GHOSTTY_DIR/build.zig" ]]; then
        echo "Initializing ghostty submodule..."
        git -C "$PROJECT_ROOT" submodule update --init --recursive vendor/ghostty
    fi
else
    echo "Error: No Ghostty source found."
    echo "Either:"
    echo "  1. Run: git submodule update --init vendor/ghostty"
    echo "  2. Pass a path: ./scripts/build-xcframework.sh /path/to/ghostty"
    exit 1
fi

# Verify zig is available
if ! command -v zig &>/dev/null; then
    echo "Error: zig not found. Install zig (see Ghostty's README for required version)."
    exit 1
fi

echo "Building libghostty with zig $(zig version)..."
cd "$GHOSTTY_DIR"

# Ghostty's build system produces GhosttyKit.xcframework at macos/GhosttyKit.xcframework
# when using -Dapp-runtime=none -Demit-xcframework=true
zig build --release=fast -Dapp-runtime=none -Demit-xcframework=true \
    -Dxcframework-target=native -Demit-macos-app=false

# The xcframework is placed in the source tree's macos/ directory
BUILT_XCFRAMEWORK="$GHOSTTY_DIR/macos/GhosttyKit.xcframework"

if [[ ! -d "$BUILT_XCFRAMEWORK" ]]; then
    echo "Error: xcframework not found at $BUILT_XCFRAMEWORK"
    exit 1
fi

# Verify the static library exists
if [[ ! -f "$BUILT_XCFRAMEWORK/macos-arm64/libghostty-fat.a" ]]; then
    echo "Error: static library not found in xcframework"
    find "$BUILT_XCFRAMEWORK" -type f | sort
    exit 1
fi

# Remove old xcframework if it exists
rm -rf "$XCFRAMEWORK_PATH"
mkdir -p "$OUTPUT_DIR"

# Copy the built xcframework, renaming to match our Package.swift binary target
cp -R "$BUILT_XCFRAMEWORK" "$XCFRAMEWORK_PATH"

# Rewrite the module map so Swift imports as 'libghostty' instead of 'GhosttyKit'
for arch_dir in "$XCFRAMEWORK_PATH"/*/; do
    if [[ -f "$arch_dir/Headers/module.modulemap" ]]; then
        cat > "$arch_dir/Headers/module.modulemap" << 'MODULEMAP'
module libghostty {
    umbrella header "ghostty.h"
    export *
}
MODULEMAP
    fi
done

# Update the Info.plist BinaryPath to match the actual library name
# The library is libghostty-fat.a, but the framework expects a binary named libghostty
# We rename it for consistency
for arch_dir in "$XCFRAMEWORK_PATH"/*/; do
    if [[ -f "$arch_dir/libghostty-fat.a" ]]; then
        mv "$arch_dir/libghostty-fat.a" "$arch_dir/libghostty.a"
    fi
done

# Rewrite Info.plist with correct paths
cat > "$XCFRAMEWORK_PATH/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AvailableLibraries</key>
    <array>
        <dict>
            <key>HeadersPath</key>
            <string>Headers</string>
            <key>LibraryIdentifier</key>
            <string>macos-arm64</string>
            <key>LibraryPath</key>
            <string>libghostty.a</string>
            <key>SupportedArchitectures</key>
            <array>
                <string>arm64</string>
            </array>
            <key>SupportedPlatform</key>
            <string>macos</string>
        </dict>
    </array>
    <key>CFBundlePackageType</key>
    <string>XFWK</string>
    <key>XCFrameworkFormatVersion</key>
    <string>1.0</string>
</dict>
</plist>
PLIST

echo ""
echo "Successfully built: $XCFRAMEWORK_PATH"
ls -lh "$XCFRAMEWORK_PATH"/macos-arm64/libghostty.a
echo "You can now build the Swift package with: swift build"
