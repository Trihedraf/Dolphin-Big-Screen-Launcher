#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_ID="dbsl"
APP_NAME="Dolphin Big Screen Launcher"
VERSION="1.0"
OUTPUT="dist"

mkdir -p "$OUTPUT"

stage_common() {
    local staging="$1"
    if [ -f "config/dbsl.json" ]; then
        cp "config/dbsl.json" "$staging/dbsl.json.example"
    fi
    if [ -f "README.md" ]; then
        cp "README.md" "$staging/README.md"
    fi
}

if [ "$(uname -s)" = "Darwin" ]; then
    # macOS: .app bundle + zip
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64) arch="intel" ;;
        arm64|aarch64) arch="arm" ;;
    esac

    app_bundle="$OUTPUT/${APP_NAME}.app"
    if [ -d "$app_bundle" ]; then rm -rf "$app_bundle"; fi

    contents="$app_bundle/Contents"
    macos_dir="$contents/MacOS"
    resources_dir="$contents/Resources"
    mkdir -p "$macos_dir" "$resources_dir"

    cp bin/dbsl "$macos_dir/$APP_ID"
    stage_common "$resources_dir"

    cat > "$contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_ID}</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.${APP_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
</dict>
</plist>
EOF

    zip_path="$OUTPUT/${APP_ID}-macos-${arch}.zip"
    if [ -f "$zip_path" ]; then rm -f "$zip_path"; fi
    ditto -c -k --keepParent "$app_bundle" "$zip_path"
    rm -rf "$app_bundle"
    echo "Created $zip_path"
else
    # Linux: tar.xz
    bundle="${APP_ID}-linux-x64"
    staging="$OUTPUT/$bundle"
    if [ -d "$staging" ]; then rm -rf "$staging"; fi
    mkdir -p "$staging"

    cp bin/dbsl "$staging/$APP_ID"
    stage_common "$staging"

    tar_path="$OUTPUT/$bundle.tar.xz"
    if [ -f "$tar_path" ]; then rm -f "$tar_path"; fi
    tar -cJf "$tar_path" -C "$OUTPUT" "$bundle"
    rm -rf "$staging"
    echo "Created $tar_path"
fi
