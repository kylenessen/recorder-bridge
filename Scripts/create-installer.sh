#!/bin/bash

# Sony Recorder Helper - Installer Package Creator
# Creates a user-friendly installer package

set -e

APP_PATH="build/export/SonyRecorderHelper.app"
PKG_NAME="SonyRecorderHelper-Installer.pkg"
INSTALL_LOCATION="/Applications"

echo "📦 Creating installer package..."

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App bundle not found at $APP_PATH"
    echo "   Please build the app first using notarize.sh"
    exit 1
fi

# Create temporary package structure
TEMP_DIR="build/pkg-temp"
mkdir -p "$TEMP_DIR/Applications"

# Copy app to temp location
cp -R "$APP_PATH" "$TEMP_DIR/Applications/"

# Create the package
echo "🔨 Building installer package..."
pkgbuild --root "$TEMP_DIR" \
         --identifier "com.recorder.bridge.SonyRecorderHelper" \
         --version "1.0" \
         --install-location "/" \
         "$PKG_NAME"

# Sign the package (if certificates are configured)
if [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    echo "✍️  Signing installer package..."
    productsign --sign "$DEVELOPER_ID_INSTALLER" "$PKG_NAME" "${PKG_NAME%.pkg}-signed.pkg"
    mv "${PKG_NAME%.pkg}-signed.pkg" "$PKG_NAME"
    echo "✅ Installer package signed"
else
    echo "⚠️  Installer package not signed - set DEVELOPER_ID_INSTALLER to enable signing"
fi

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ Installer package created: $PKG_NAME"
echo ""
echo "The installer will:"
echo "• Install Sony Recorder Helper to /Applications"
echo "• Preserve any existing settings"
echo "• Require administrator privileges"
echo ""
echo "Next steps:"
echo "1. Test the installer on a clean system"
echo "2. Notarize the package if desired"
echo "3. Distribute via your preferred method"