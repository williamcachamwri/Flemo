#!/bin/bash
set -euo pipefail

APP_NAME="Flemo"
OLD_APP_NAME="EmojiGFast"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_PATH="/Applications/$APP_NAME.app"
OLD_INSTALL_PATH="/Applications/$OLD_APP_NAME.app"

if [ -z "${SIGN_IDENTITY:-}" ]; then
  PREFERRED_SIGN_IDENTITY="Apple Development: levinhkhang93@gmail.com (DSGXR894W5)"
  if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"$PREFERRED_SIGN_IDENTITY\""; then
    SIGN_IDENTITY="$PREFERRED_SIGN_IDENTITY"
  else
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')"
  fi
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

echo "Building $APP_NAME..."
swift build -c release --product "$APP_NAME"

echo "Creating .app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

cp "$PROJECT_DIR/Sources/Flemo/Resources/Flemo.icns" "$APP_BUNDLE/Contents/Resources/"
cp "$PROJECT_DIR/Sources/Flemo/Resources/emoji-data.json" "$APP_BUNDLE/Contents/Resources/"

RESOURCE_BUNDLE="$BUILD_DIR/out/Products/Release/Flemo_Flemo.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
  cp -r "$RESOURCE_BUNDLE/Contents/Resources/" "$APP_BUNDLE/Contents/Resources/"
fi

echo "Code signing..."
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_BUNDLE"

echo "✅ App bundle created: $APP_BUNDLE"
echo "   Signed with identity: $SIGN_IDENTITY"

if [ "$APP_BUNDLE" != "$INSTALL_PATH" ]; then
  echo "Deploying to $INSTALL_PATH..."
  rm -rf "$INSTALL_PATH"
  cp -R "$APP_BUNDLE" "$INSTALL_PATH"
  echo "✅ Deployed to $INSTALL_PATH"
fi

if [ -d "$OLD_INSTALL_PATH" ]; then
  echo "Removing old app bundle at $OLD_INSTALL_PATH..."
  rm -rf "$OLD_INSTALL_PATH"
fi

echo ""
echo "If macOS still shows stale permissions from the old ad-hoc build, reset once before re-granting:"
echo "  tccutil reset Accessibility com.flemo.app"
echo "  tccutil reset ListenEvent com.flemo.app"
echo ""
echo "Run with: open \"$APP_BUNDLE\""
