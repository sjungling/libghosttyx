#!/usr/bin/env bash
#
# Fetches all dependencies needed to build libghostty offline.
#
# Usage:
#   ./scripts/fetch-deps.sh [path-to-ghostty-repo]
#
# If no path is provided, uses the vendor/ghostty submodule.
# Idempotent — safe to run multiple times.
#
# What this does:
#   1. Initialize/update the vendor/ghostty submodule (skipped if external path provided)
#   2. Verify Zig version matches .zig-version
#   3. Prefetch Zig build dependencies (zig build --fetch)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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
    echo "Using external Ghostty checkout: $GHOSTTY_DIR"
else
    GHOSTTY_DIR="$PROJECT_ROOT/vendor/ghostty"
    echo "Initializing vendor/ghostty submodule..."
    git -C "$PROJECT_ROOT" submodule update --init --recursive vendor/ghostty
    echo "Submodule up to date."
fi

if [[ ! -f "$GHOSTTY_DIR/build.zig" ]]; then
    echo "Error: build.zig not found in $GHOSTTY_DIR — is this a valid Ghostty checkout?"
    exit 1
fi

# --- Prefetch Zig build dependencies ---
echo "Prefetching Zig build dependencies..."
cd "$GHOSTTY_DIR"
zig build --fetch

echo ""
echo "All dependencies fetched. You can now build with:"
echo "  make xcframework"
