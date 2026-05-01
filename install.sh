#!/bin/bash

# Configuration
APP_NAME="SmartIME"
BUILD_DIR=".build/debug"
INSTALL_DIR="$HOME/Library/Input Methods"
DEST="$INSTALL_DIR/$APP_NAME.app"

echo "🚀 Building SmartIMEApp..."
swift build --product SmartIMEApp

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "📦 Packaging $APP_NAME.app..."

# Create .app structure
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/SmartIMEApp" "$APP_NAME.app/Contents/MacOS/"

# Copy Info.plist
cp "Sources/SmartIMEApp/Info.plist" "$APP_NAME.app/Contents/"

# Create PkgInfo
echo "APPL????" > "$APP_NAME.app/Contents/PkgInfo"

echo "✍️  Signing $APP_NAME.app (Ad-hoc)..."
codesign --force --deep --sign - "$APP_NAME.app"


echo "🛑 Stopping existing process..."
pkill -f "SmartIME" || true

echo "📂 Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
rm -rf "$DEST"
cp -R "$APP_NAME.app" "$DEST"

# Clean up local artifact
rm -rf "$APP_NAME.app"

echo "✅ Installed successfully!"
echo "➡️  Go to System Settings -> Keyboard -> Input Sources -> Edit -> + -> Chinese (Traditional) -> SmartIME to enable it."
echo "   (You may need to log out and log back in for the system to detect the new Input Method)"
