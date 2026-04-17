#!/bin/bash
set -e

APP_NAME="MacCove"
BUNDLE_ID="com.maccove.app"
APP_DIR="/Applications/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building ${APP_NAME} (release)..."
swift build -c release 2>&1 | tail -3

BINARY=".build/release/${APP_NAME}"
if [ ! -f "$BINARY" ]; then
    echo "Error: Build failed — binary not found at $BINARY"
    exit 1
fi

# Kill running instance
echo "Stopping any running instance..."
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

echo "Creating app bundle at ${APP_DIR}..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BINARY" "$MACOS_DIR/${APP_NAME}"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/Info.plist"

# Copy resource bundle if it exists
RESOURCE_BUNDLE=".build/release/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

# Ad-hoc code sign (required for macOS to trust the app)
echo "Code signing..."
codesign --force --deep --sign - \
    --entitlements MacCove.entitlements \
    "$APP_DIR" 2>&1

echo ""
echo "Installed to ${APP_DIR}"
echo ""

# Open the app
echo "Launching ${APP_NAME}..."
open "$APP_DIR"

echo "Done! ${APP_NAME} is running."
echo ""
echo "To open on login, go to:"
echo "  System Settings > General > Login Items > add MacCove"
echo ""
echo "Or run:  ./install.sh --login"
if [ "$1" = "--login" ]; then
    echo ""
    echo "Adding to login items..."
    osascript -e "
        tell application \"System Events\"
            make login item at end with properties {path:\"${APP_DIR}\", hidden:false}
        end tell
    " 2>&1
    echo "MacCove will now open on login."
fi
