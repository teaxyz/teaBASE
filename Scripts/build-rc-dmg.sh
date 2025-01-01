#!/usr/bin/env -S pkgx +create-dmg bash -eo pipefail

cd "$(dirname "$0")/.."

# Check for required tools
command -v xcodebuild >/dev/null 2>&1 || { echo >&2 "xcodebuild is not installed. Aborting."; exit 1; }
command -v codesign >/dev/null 2>&1 || { echo >&2 "codesign is not installed. Aborting."; exit 1; }
command -v create-dmg >/dev/null 2>&1 || { echo >&2 "create-dmg is not installed. Aborting."; exit 1; }

# Ensure version is provided
if ! test "$1"; then
  echo "usage $0 <VERSION>" >&2
  exit 1
fi

v=$1-rc

# Create temp xcconfig file and setup trap for cleanup
tmp_xcconfig="$(mktemp)"
trap 'rm -f "$tmp_xcconfig"' EXIT
echo "MARKETING_VERSION = $v" > "$tmp_xcconfig"

# Build the application
if ! xcodebuild -scheme teaBASE -configuration Release -xcconfig "$tmp_xcconfig" -derivedDataPath ./Build build; then
  echo "xcodebuild failed" >&2
  exit 1
fi

# Code sign the application
if ! codesign --entitlements ./Sundries/teaBASE.entitlements --deep --force --options runtime --sign "Developer ID Application: Tea Inc. (7WV56FL599)" build/Build/Products/Release/teaBASE.prefPane; then
  echo "codesign failed" >&2
  exit 1
fi

rm -f teaBASE-$v.dmg
create-dmg --volname "teaBASE v$1" --window-size 435 435 --window-pos 538 273 --filesystem APFS --format ULFO --background ./Resources/dmg-bg@2x.png --icon teaBASE.prefPane 217.5 223.5 --hide-extension teaBASE.prefPane --icon-size 100 teaBASE-$v.dmg build/Build/Products/Release/teaBASE.prefPane

# Ensure DMG file exists before signing
if [ ! -f "./teaBASE-$v.dmg" ]; then
  echo "DMG file not found after creation." >&2
  exit 1
fi

# Signing the DMG
if ! codesign --force --sign "Developer ID Application: Tea Inc. (7WV56FL599)" ./teaBASE-$v.dmg; then
  echo "codesign for DMG failed" >&2
  exit 1
fi
