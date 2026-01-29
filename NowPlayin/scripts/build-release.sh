#!/bin/bash
set -e

# Build, sign, notarize, and package NowPlayin for distribution
#
# Required environment variables:
#   APPLE_ID       - Your Apple ID email
#   TEAM_ID        - Your Apple Developer Team ID
#   APP_PASSWORD   - App-specific password (generate at appleid.apple.com)
#
# Optional:
#   SKIP_NOTARIZE  - Set to 1 to skip notarization (for testing)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="NowPlayin"
SCHEME="NowPlayin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
error() { echo -e "${RED}Error:${NC} $1"; exit 1; }

# Check required env vars for notarization
check_notarize_env() {
    if [[ "$SKIP_NOTARIZE" == "1" ]]; then
        warn "Skipping notarization (SKIP_NOTARIZE=1)"
        return 1
    fi

    if [[ -z "$APPLE_ID" || -z "$TEAM_ID" || -z "$APP_PASSWORD" ]]; then
        warn "Missing APPLE_ID, TEAM_ID, or APP_PASSWORD - skipping notarization"
        warn "Set these environment variables to enable notarization"
        return 1
    fi
    return 0
}

# Clean previous builds
info "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build archive
info "Building release archive..."
cd "$PROJECT_DIR"
xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive \
    | grep -E "(error:|warning:|BUILD|ARCHIVE)" || true

if [[ ! -d "$BUILD_DIR/$APP_NAME.xcarchive" ]]; then
    error "Archive failed - check build output above"
fi

# Export app
info "Exporting app..."
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportPath "$BUILD_DIR/export" \
    -exportOptionsPlist "$PROJECT_DIR/ExportOptions.plist" \
    | grep -E "(error:|warning:|EXPORT)" || true

APP_PATH="$BUILD_DIR/export/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
    error "Export failed - check output above"
fi

info "App exported to: $APP_PATH"

# Notarize
if check_notarize_env; then
    info "Creating zip for notarization..."
    cd "$BUILD_DIR/export"
    zip -r -q "$APP_NAME.zip" "$APP_NAME.app"

    info "Submitting for notarization (this may take a few minutes)..."
    xcrun notarytool submit "$APP_NAME.zip" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD" \
        --wait

    info "Stapling notarization ticket..."
    xcrun stapler staple "$APP_NAME.app"

    # Re-create zip with stapled app
    rm "$APP_NAME.zip"
    zip -r -q "$APP_NAME.zip" "$APP_NAME.app"

    info "Notarization complete!"
else
    # Create zip without notarization
    cd "$BUILD_DIR/export"
    zip -r -q "$APP_NAME.zip" "$APP_NAME.app"
fi

# Get version
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.0.0")
FINAL_ZIP="$BUILD_DIR/$APP_NAME-$VERSION.zip"
mv "$BUILD_DIR/export/$APP_NAME.zip" "$FINAL_ZIP"

# Create DMG
FINAL_DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
info "Creating DMG..."
rm -f "$FINAL_DMG"

if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 450 190 \
        "$FINAL_DMG" \
        "$APP_PATH" \
        2>/dev/null || true

    if [[ -f "$FINAL_DMG" ]]; then
        info "DMG created: $FINAL_DMG"
    else
        warn "DMG creation failed - falling back to hdiutil"
        hdiutil create -volname "$APP_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$FINAL_DMG"
    fi
else
    warn "create-dmg not found - using basic hdiutil"
    hdiutil create -volname "$APP_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$FINAL_DMG"
fi

info "Build complete!"
echo ""
echo "  App:  $APP_PATH"
echo "  DMG:  $FINAL_DMG"
echo "  Zip:  $FINAL_ZIP"
echo ""

if [[ "$SKIP_NOTARIZE" != "1" && -n "$APPLE_ID" ]]; then
    echo "  Ready for distribution!"
else
    echo "  Note: App is not notarized - users will see Gatekeeper warnings"
fi
