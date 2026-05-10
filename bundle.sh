#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Virtual Overlay"
PRODUCT_NAME="VirtualOverlay"
BUNDLE_IDENTIFIER="com.ormasoftchile.virtualoverlay"
VERSION="0.1.0"
BUILD_NUMBER="1"
MINIMUM_SYSTEM_VERSION="13.0"
AUTHOR="Ormasoft Chile"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
EXECUTABLE_PATH="${MACOS_DIR}/${APP_NAME}"
BUILT_BINARY=".build/release/${PRODUCT_NAME}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift is required to build ${APP_NAME}. Install Xcode or the Xcode Command Line Tools." >&2
  exit 1
fi

if ! command -v codesign >/dev/null 2>&1; then
  echo "warning: codesign was not found; the app bundle will be built but not ad-hoc signed." >&2
  CODESIGN_AVAILABLE=0
else
  CODESIGN_AVAILABLE=1
fi

echo "Building ${PRODUCT_NAME} in release mode..."
swift build -c release --product "${PRODUCT_NAME}"

if [[ ! -x "${BUILT_BINARY}" ]]; then
  echo "error: expected built executable at ${BUILT_BINARY}, but it was not found or is not executable." >&2
  exit 1
fi

echo "Creating ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_IDENTIFIER}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MINIMUM_SYSTEM_VERSION}</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 ${AUTHOR}. All rights reserved.</string>
</dict>
</plist>
PLIST

printf "APPL????" > "${CONTENTS_DIR}/PkgInfo"
cp "${BUILT_BINARY}" "${EXECUTABLE_PATH}"
chmod 755 "${EXECUTABLE_PATH}"

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "${APP_BUNDLE}" || echo "warning: could not clear extended attributes on ${APP_BUNDLE}." >&2
fi

if [[ "${CODESIGN_AVAILABLE}" -eq 1 ]]; then
  echo "Ad-hoc signing ${APP_BUNDLE}..."
  if ! codesign --force --deep --sign - "${APP_BUNDLE}"; then
    echo "warning: ad-hoc signing failed. The app bundle was still created." >&2
  fi
fi

echo
echo "Built: ${APP_BUNDLE}"
echo "Install: mv \"${APP_BUNDLE}\" /Applications/"
echo "Run at login: System Settings → General → Login Items & Extensions → Open at Login → +, then pick /Applications/${APP_NAME}.app"
