#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p bin

ODIN_VERSION="dev-2026-07a"
ODIN_DIR="tools/odin"
ODIN_BIN="$ODIN_DIR/odin"

# Download Odin if not found.
if [ -f "$ODIN_BIN" ]; then
    ODIN="$ODIN_BIN"
else
    echo "Odin not found. Downloading Odin $ODIN_VERSION..."

    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64) ARCH_PART="amd64" ;;
        arm64|aarch64) ARCH_PART="arm64" ;;
        *) echo "Unsupported arch: $ARCH"; exit 1 ;;
    esac

    OS_PART="linux"
    if [ "$(uname -s)" = "Darwin" ]; then
        OS_PART="macos"
    fi

    mkdir -p "$ODIN_DIR"

    TARBALL="odin-${OS_PART}-${ARCH_PART}-${ODIN_VERSION}.tar.gz"
    URL="https://github.com/odin-lang/Odin/releases/download/${ODIN_VERSION}/${TARBALL}"

    TMPFILE=$(mktemp)
    curl -L -o "$TMPFILE" "$URL"
    tar -xzf "$TMPFILE" -C "$ODIN_DIR" --strip-components=1
    rm -f "$TMPFILE"

    if [ ! -f "$ODIN_BIN" ]; then
        echo "Error: Odin download/extraction failed. Expected: $ODIN_BIN"
        exit 1
    fi

    chmod +x "$ODIN_BIN"
    echo "Odin installed: $ODIN_BIN"
    "$ODIN_BIN" version
    ODIN="$ODIN_BIN"
fi

VERSION=$(tr -d '[:space:]' < VERSION)

$ODIN build src -out:bin/dbsl -define:DBSL_VERSION="$VERSION" "$@"
echo "Build complete: bin/dbsl"
