#!/usr/bin/env -S pkgx +create-dmg bash -eo pipefail

if ! test "$1"; then
  echo "usage $0 <VERSION>" >&2
  exit 1
fi

v=$1-rc

tmp_xcconfig="$(mktemp)"
echo "MARKETING_VERSION = $v" > "$tmp_xcconfig"

xcodebuild \
  -scheme teaBASE \
  -configuration Release \
  -xcconfig "$tmp_xcconfig" \
  -derivedDataPath ./build \
  build

codesign \
  --entitlements ~/src/teaBASE/Sundries/teaBASE.entitlements \
  --deep --force \
  --options runtime \
  --sign "Developer ID Application: Tea Inc. (7WV56FL599)" \
  build/Build/Products/Release/teaBASE.prefPane

rm -f teaBASE-$v.dmg

#NOTE UDZO is half the size of the supposedly “better” ULMO

create-dmg \
  --volname "teaBASE v$1" \
  --window-size 435 435 \
  --window-pos 538 273 \
  --filesystem APFS \
  --format UDZO \
  --background ./Resources/dmg-bg@2x.png \
  --icon teaBASE.prefPane 217.5 223.5 \
  --hide-extension teaBASE.prefPane \
  --icon-size 100 \
  teaBASE-$v.dmg \
  build/Build/Products/Release/teaBASE.prefPane

codesign \
  --force \
  --sign "Developer ID Application: Tea Inc. (7WV56FL599)" \
  ./teaBASE-$v.dmg
