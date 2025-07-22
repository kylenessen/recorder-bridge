#!/bin/bash

# Sony Recorder Helper - Notarization Script
# This script builds, signs, and notarizes the app for distribution

set -e

# Configuration - Update these values before running
DEVELOPER_ID_APPLICATION=""  # e.g., "Developer ID Application: Your Name (TEAMID)"
DEVELOPER_ID_INSTALLER=""    # e.g., "Developer ID Installer: Your Name (TEAMID)"
APPLE_ID=""                  # Your Apple ID email
TEAM_ID=""                   # Your Apple Developer Team ID
APP_PASSWORD=""              # App-specific password for notarization

# Build settings
PROJECT_PATH="SonyRecorderHelper.xcodeproj"
SCHEME="SonyRecorderHelper"
CONFIGURATION="Release"
BUILD_DIR="build/Release"
APP_NAME="SonyRecorderHelper.app"
DMG_NAME="SonyRecorderHelper.dmg"
ZIP_NAME="SonyRecorderHelper.zip"

echo "🏗️  Building Sony Recorder Helper for distribution..."

# Clean and build
xcodebuild clean -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION"
xcodebuild archive -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" -archivePath "build/$SCHEME.xcarchive"

# Export the app
xcodebuild -exportArchive -archivePath "build/$SCHEME.xcarchive" -exportPath "build/export" -exportOptionsPlist Scripts/ExportOptions.plist

# Verify signing
echo "🔍 Verifying code signature..."
codesign --verify --verbose=2 "build/export/$APP_NAME"

# Create distribution package
echo "📦 Creating distribution package..."
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi

# Create a simple disk image
hdiutil create -volname "Sony Recorder Helper" -srcfolder "build/export/$APP_NAME" -ov -format UDZO "$DMG_NAME"

# Sign the disk image
echo "✍️  Signing disk image..."
codesign --force --sign "$DEVELOPER_ID_APPLICATION" "$DMG_NAME"

# Notarize the disk image
echo "📤 Submitting for notarization..."
if [ -z "$APPLE_ID" ] || [ -z "$APP_PASSWORD" ] || [ -z "$TEAM_ID" ]; then
    echo "⚠️  Notarization skipped - Apple ID credentials not configured"
    echo "   Set APPLE_ID, APP_PASSWORD, and TEAM_ID variables to enable notarization"
else
    xcrun notarytool submit "$DMG_NAME" --apple-id "$APPLE_ID" --password "$APP_PASSWORD" --team-id "$TEAM_ID" --wait
    
    # Staple the notarization
    echo "📎 Stapling notarization..."
    xcrun stapler staple "$DMG_NAME"
    
    echo "✅ Notarization complete!"
fi

echo "🎉 Distribution package ready: $DMG_NAME"

# Also create a ZIP archive
cd "build/export"
zip -r "../../$ZIP_NAME" "$APP_NAME"
cd ../..

echo "📁 Also created ZIP archive: $ZIP_NAME"
echo ""
echo "Next steps:"
echo "1. Test the app on a clean macOS system"
echo "2. Verify notarization with: spctl -a -vvv -t install $DMG_NAME"
echo "3. Distribute via your preferred method"