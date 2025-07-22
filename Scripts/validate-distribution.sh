#!/bin/bash

# Sony Recorder Helper - Distribution Validation Script
# This script validates the signed and notarized app bundle

set -e

APP_PATH="$1"
if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 <path-to-app-or-dmg>"
    echo "Example: $0 SonyRecorderHelper.dmg"
    echo "Example: $0 build/export/SonyRecorderHelper.app"
    exit 1
fi

if [ ! -e "$APP_PATH" ]; then
    echo "❌ File not found: $APP_PATH"
    exit 1
fi

echo "🔍 Validating distribution package: $APP_PATH"
echo ""

# Check if it's a DMG or app bundle
if [[ "$APP_PATH" == *.dmg ]]; then
    echo "📀 Validating DMG file..."
    
    # Check DMG signature
    echo "Checking DMG signature..."
    codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E "(Authority|TeamIdentifier|Identifier)"
    
    # Verify DMG
    echo "Verifying DMG..."
    codesign --verify --verbose=2 "$APP_PATH"
    
    # Check notarization stapling
    echo "Checking notarization stapling..."
    if xcrun stapler validate "$APP_PATH"; then
        echo "✅ DMG is properly notarized and stapled"
    else
        echo "⚠️  DMG notarization check failed"
    fi
    
    # Check Gatekeeper assessment
    echo "Testing Gatekeeper assessment..."
    if spctl -a -vvv -t install "$APP_PATH"; then
        echo "✅ DMG passes Gatekeeper assessment"
    else
        echo "❌ DMG fails Gatekeeper assessment"
    fi
    
elif [[ "$APP_PATH" == *.app ]]; then
    echo "📱 Validating app bundle..."
    
    # Check app signature
    echo "Checking app signature..."
    codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E "(Authority|TeamIdentifier|Identifier)"
    
    # Verify app
    echo "Verifying app..."
    codesign --verify --verbose=2 "$APP_PATH"
    
    # Deep verification
    echo "Deep verification..."
    codesign --verify --deep --verbose=2 "$APP_PATH"
    
    # Check notarization stapling
    echo "Checking notarization stapling..."
    if xcrun stapler validate "$APP_PATH"; then
        echo "✅ App is properly notarized and stapled"
    else
        echo "⚠️  App notarization check failed"
    fi
    
    # Check Gatekeeper assessment
    echo "Testing Gatekeeper assessment..."
    if spctl -a -vvv -t exec "$APP_PATH"; then
        echo "✅ App passes Gatekeeper assessment"
    else
        echo "❌ App fails Gatekeeper assessment"
    fi
    
else
    echo "❌ Unsupported file type. Please provide a .app bundle or .dmg file"
    exit 1
fi

echo ""
echo "🎉 Validation complete!"
echo ""
echo "Distribution checklist:"
echo "□ Code signed with Developer ID Application certificate"
echo "□ Notarized by Apple"
echo "□ Stapled with notarization ticket"
echo "□ Passes Gatekeeper assessment"
echo "□ Tested on clean macOS system"
echo "□ Full Disk Access instructions provided"