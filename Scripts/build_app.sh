#!/bin/bash
set -e

# ==========================================
# CutX App Bundle Builder
# ==========================================

echo "🔨 Building CutX in Release configuration..."
swift build -c release

APP_NAME="CutX"
BUILD_DIR="./build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Find release binary
BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"

echo "📦 Assembling ${APP_NAME}.app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable binary
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
if [ -f "Resources/Info.plist" ]; then
    cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
fi

# Ad-hoc code signing for local execution
echo "🔏 Signing App bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ Successfully built: ${APP_BUNDLE}"
