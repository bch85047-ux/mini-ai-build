#!/usr/bin/env bash
# dsh iOS Web 壳一键打包（macOS + Xcode）
#   ./build-ipa.sh          产出 build/dsh.ipa（未签名，Sideloadly/AltStore/TrollStore 自动重签）
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"; BUILD="$ROOT/build"

need() { command -v "$1" >/dev/null || { echo "缺少 $1：$2"; exit 1; }; }
need xcodebuild "装 Xcode"
command -v xcodegen >/dev/null || { command -v brew >/dev/null && brew install xcodegen; }
xcodegen generate

rm -rf "$BUILD"; mkdir -p "$BUILD"
xcodebuild -project dsh-ios.xcodeproj -scheme dsh -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -archivePath "$BUILD/dsh.xcarchive" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= archive

APP="$BUILD/dsh.xcarchive/Products/Applications/dsh.app"
[ -d "$APP" ] || { echo "编译失败，没找到 $APP"; exit 1; }
mkdir -p "$BUILD/Payload"
cp -R "$APP" "$BUILD/Payload/"
( cd "$BUILD" && zip -qry dsh.ipa Payload )
echo "✅ $BUILD/dsh.ipa  ($(du -h "$BUILD/dsh.ipa" | cut -f1))"
