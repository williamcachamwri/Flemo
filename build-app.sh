#!/bin/bash
set -euo pipefail

OLD_APP_NAME="EmojiGFast"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
OLD_INSTALL_PATH="/Applications/$OLD_APP_NAME.app"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
BUILD_CONFIGURATION="$(printf '%s' "$BUILD_CONFIGURATION" | tr '[:upper:]' '[:lower:]')"

case "$BUILD_CONFIGURATION" in
  debug)
    SWIFT_CONFIGURATION="debug"
    XCODE_CONFIGURATION="Debug"
    UPDATE_CHANNEL="debug"
    APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Flemo Debug}"
    APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.flemo.debug}"
    DEFAULT_APPCAST_URL="${FLEMO_DEBUG_APPCAST_URL:-https://williamcachamwri.github.io/Flemo/debug-appcast.xml}"
    DEFAULT_PUBLIC_ED_KEY="${FLEMO_DEBUG_SPARKLE_PUBLIC_KEY:-kmgFrpsnhiRikJxjk0bdQYDP0Rp11IXJh1XKTGA0b+U=}"
    ;;
  release)
    SWIFT_CONFIGURATION="release"
    XCODE_CONFIGURATION="Release"
    UPDATE_CHANNEL="release"
    APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Flemo}"
    APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.flemo.app}"
    DEFAULT_APPCAST_URL="${FLEMO_RELEASE_APPCAST_URL:-https://williamcachamwri.github.io/Flemo/appcast.xml}"
    DEFAULT_PUBLIC_ED_KEY="${FLEMO_RELEASE_SPARKLE_PUBLIC_KEY:-4slBdkmHZvJCso7Heq+LuWurh8RbBpH+tna43b5lks0=}"
    ;;
  *)
    echo "Unsupported BUILD_CONFIGURATION: $BUILD_CONFIGURATION" >&2
    echo "Use BUILD_CONFIGURATION=debug or BUILD_CONFIGURATION=release." >&2
    exit 1
    ;;
esac

APP_EXECUTABLE_NAME="Flemo"
APPCAST_URL="${SPARKLE_FEED_URL:-$DEFAULT_APPCAST_URL}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-$DEFAULT_PUBLIC_ED_KEY}"
SPARKLE_ENABLE_AUTOMATIC_CHECKS="${SPARKLE_ENABLE_AUTOMATIC_CHECKS:-false}"
SPARKLE_AUTOMATICALLY_UPDATE="${SPARKLE_AUTOMATICALLY_UPDATE:-false}"
APP_BUNDLE="$BUILD_DIR/$APP_DISPLAY_NAME.app"
INSTALL_PATH="${INSTALL_PATH:-/Applications/$APP_DISPLAY_NAME.app}"
INSTALL_APP="${INSTALL_APP:-1}"

if [ -z "${SIGN_IDENTITY:-}" ]; then
  PREFERRED_SIGN_IDENTITY="Apple Development: levinhkhang93@gmail.com (DSGXR894W5)"
  if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"$PREFERRED_SIGN_IDENTITY\""; then
    SIGN_IDENTITY="$PREFERRED_SIGN_IDENTITY"
  else
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')"
  fi
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

echo "Building $APP_DISPLAY_NAME ($UPDATE_CHANNEL)..."
swift build -c "$SWIFT_CONFIGURATION" --product "$APP_EXECUTABLE_NAME"

echo "Creating .app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

cp "$BUILD_DIR/$SWIFT_CONFIGURATION/$APP_EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "$APP_EXECUTABLE_NAME" "$INFO_PLIST"
plutil -replace CFBundleName -string "$APP_DISPLAY_NAME" "$INFO_PLIST"
plutil -replace CFBundleIdentifier -string "$APP_BUNDLE_ID" "$INFO_PLIST"
plutil -replace SUFeedURL -string "$APPCAST_URL" "$INFO_PLIST"
plutil -replace SUEnableAutomaticChecks -bool "$SPARKLE_ENABLE_AUTOMATIC_CHECKS" "$INFO_PLIST"
plutil -replace SUAutomaticallyUpdate -bool "$SPARKLE_AUTOMATICALLY_UPDATE" "$INFO_PLIST"
plutil -replace FlemoUpdateChannel -string "$UPDATE_CHANNEL" "$INFO_PLIST"

/usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$INFO_PLIST" 2>/dev/null || true
if [ -n "$SPARKLE_PUBLIC_ED_KEY" ]; then
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_ED_KEY" "$INFO_PLIST"
fi

cp "$PROJECT_DIR/Sources/Flemo/Resources/Flemo.icns" "$APP_BUNDLE/Contents/Resources/"
cp "$PROJECT_DIR/Sources/Flemo/Resources/emoji-data.json" "$APP_BUNDLE/Contents/Resources/"

RESOURCE_BUNDLE="$BUILD_DIR/out/Products/$XCODE_CONFIGURATION/Flemo_Flemo.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
  cp -r "$RESOURCE_BUNDLE/Contents/Resources/" "$APP_BUNDLE/Contents/Resources/"
fi

SPARKLE_FRAMEWORK="$(find "$BUILD_DIR" -path "*/Sparkle.framework" -type d 2>/dev/null | head -n 1)"
if [ -z "$SPARKLE_FRAMEWORK" ]; then
  echo "Sparkle.framework was not found in $BUILD_DIR." >&2
  exit 1
fi
ditto "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

EXECUTABLE_PATH="$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE_NAME"
if ! otool -l "$EXECUTABLE_PATH" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXECUTABLE_PATH"
fi

echo "Code signing..."
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
codesign --force --deep --options runtime --entitlements "$PROJECT_DIR/Flemo.entitlements" --sign "$SIGN_IDENTITY" "$APP_BUNDLE"

echo "✅ App bundle created: $APP_BUNDLE"
echo "   Bundle ID: $APP_BUNDLE_ID"
echo "   Update channel: $UPDATE_CHANNEL"
echo "   Appcast URL: $APPCAST_URL"
echo "   Signed with identity: $SIGN_IDENTITY"

if [ "$INSTALL_APP" = "1" ] && [ "$APP_BUNDLE" != "$INSTALL_PATH" ]; then
  echo "Deploying to $INSTALL_PATH..."
  rm -rf "$INSTALL_PATH"
  cp -R "$APP_BUNDLE" "$INSTALL_PATH"
  echo "✅ Deployed to $INSTALL_PATH"
fi

if [ "$INSTALL_APP" = "1" ] && [ "$BUILD_CONFIGURATION" = "release" ] && [ -d "$OLD_INSTALL_PATH" ]; then
  echo "Removing old app bundle at $OLD_INSTALL_PATH..."
  rm -rf "$OLD_INSTALL_PATH"
fi

echo ""
echo "If macOS still shows stale permissions from the old ad-hoc build, reset once before re-granting:"
echo "  tccutil reset Accessibility $APP_BUNDLE_ID"
echo "  tccutil reset ListenEvent $APP_BUNDLE_ID"
echo ""
echo "Run with: open \"$APP_BUNDLE\""
