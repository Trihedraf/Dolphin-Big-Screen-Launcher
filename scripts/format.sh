#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

ODINFMT_VERSION="dev-2026-05"
OLS_DIR="tools/ols"
ODINFMT_BIN="$OLS_DIR/odinfmt"

# Find odinfmt: PATH first, then local build.
if command -v odinfmt &>/dev/null; then
    ODINFMT="odinfmt"
elif ls tools/ols/odinfmt-* &>/dev/null 2>&1; then
    ODINFMT="$(echo tools/ols/odinfmt-*)"
else
    echo "odinfmt not found. Downloading and building ols $ODINFMT_VERSION..."

    # Find Odin compiler.
    if [ -f "tools/odin/odin" ]; then
        ODIN="tools/odin/odin"
    elif command -v odin &>/dev/null; then
        ODIN="odin"
    else
        echo "Error: Odin compiler not found."
        echo "Install Odin or run scripts/build.sh first."
        exit 1
    fi

    OS_NAME="$(uname -s)"
    ARCH="$(uname -m)"
    case "$OS_NAME" in
        Linux*)  OLS_PLATFORM="unknown-linux-gnu" ;;
        Darwin*) OLS_PLATFORM="darwin" ;;
        *) echo "Unsupported OS: $OS_NAME"; exit 1 ;;
    esac
    case "$ARCH" in
        x86_64|amd64) ARCH_PART="x86_64" ;;
        arm64|aarch64) ARCH_PART="arm64" ;;
        *) echo "Unsupported arch: $ARCH"; exit 1 ;;
    esac

    OLS_TARBALL="ols-${ARCH_PART}-${OLS_PLATFORM}.zip"
    OLS_URL="https://github.com/DanielGavin/ols/releases/download/$ODINFMT_VERSION/$OLS_TARBALL"

    mkdir -p "$OLS_DIR"
    echo "Downloading $OLS_URL ..."
    curl -L -o "/tmp/ols-download.zip" "$OLS_URL"
    echo "Extracting..."
    unzip -o "/tmp/ols-download.zip" -d "$OLS_DIR"
    rm -f "/tmp/ols-download.zip"

    chmod +x "$OLS_DIR"/odinfmt-*
    ODINFMT="$(echo "$OLS_DIR"/odinfmt-*)"
fi

echo "Using: $ODINFMT"

# Format all .odin files in src/.
echo "Formatting source files..."
"$ODINFMT" -path:src -w
echo "Done."
