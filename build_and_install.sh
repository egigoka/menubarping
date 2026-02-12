#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$SCRIPT_DIR/MenubarPing.xcodeproj"
SCHEME="MenubarPing"
CONFIGURATION="Release"
DERIVED_DATA_PATH="$SCRIPT_DIR/build"
APP_NAME="MenubarPing.app"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"
TARGET_APP_PATH="/Applications/$APP_NAME"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "error: project not found at $PROJECT_PATH" >&2
  exit 1
fi

echo "Building $APP_NAME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -d "$BUILT_APP_PATH" ]]; then
  echo "error: built app not found at $BUILT_APP_PATH" >&2
  exit 1
fi

echo "Installing to $TARGET_APP_PATH ..."
echo "Stopping running app (if any)..."
pkill -x "MenubarPing" >/dev/null 2>&1 || true

if [[ -d "$TARGET_APP_PATH" ]]; then
  rm -rf "$TARGET_APP_PATH"
fi

cp -R "$BUILT_APP_PATH" "/Applications/"

echo "Relaunching app..."
open -a "$TARGET_APP_PATH"

echo "Done: $TARGET_APP_PATH"
