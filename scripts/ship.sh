#!/usr/bin/env bash
# 构建 WireDeck → dmg（默认，macOS）或 Windows 便携 zip（--win32）→ 上传并发布到 VaKao 软件中心
# 用法: scripts/ship.sh [--win32] [--no-build] [--dry-run] [--no-publish]
#   --win32     改出 Windows x64 便携 zip；不加则保持原有 macOS dmg 行为
#   --no-build  跳过构建，直接用已有产物上传
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="${HUB_CLI:-/Users/woyuxiaji/Rouarn/AliyunCloud/vakao-hub/tools/hub-cli.mjs}"

# wails.json 的版本号。macOS 用 python3，Windows（Git Bash）没有则回落 node。
read_version() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json;print(json.load(open('$1'))['info']['productVersion'])"
  else
    node -p "require('$1').info.productVersion"
  fi
}

VERSION=$(read_version "$ROOT/wails.json")
CODE=$(echo "$VERSION" | awk -F. '{printf "%d", $1*100+$2*10+$3}')

PLATFORM="darwin"
BUILD=1
PASSTHRU=()
for arg in "$@"; do
  case "$arg" in
    --win32) PLATFORM="win32" ;;
    --macos) PLATFORM="darwin" ;;
    --no-build) BUILD=0 ;;
    *) PASSTHRU+=("$arg") ;;
  esac
done

if [ "$PLATFORM" = "win32" ]; then
  # Windows 包 = exe + platform-tools（adb/aapt2）+ scrcpy，组装逻辑在 package-windows.ps1，
  # 与 .github/workflows/ci.yml 的 build-windows job 保持一致。
  ZIP="$ROOT/build/bin/WireDeck-windows-amd64.zip"
  if [ "$BUILD" = 1 ]; then
    powershell -ExecutionPolicy Bypass -File "$ROOT/scripts/package-windows.ps1"
  fi
  [ -f "$ZIP" ] || { echo "找不到产物 $ZIP" >&2; exit 1; }
  exec node "$CLI" release --app wiredeck --version "$VERSION" --code "$CODE" \
    --file "$ZIP" --platform win32 --arch x64 --format zip --min-os 10.0 \
    --notes "WireDeck $VERSION" ${PASSTHRU[@]+"${PASSTHRU[@]}"}
fi

DMG="$ROOT/build/WireDeck-${VERSION}.dmg"
if [ "$BUILD" = 1 ]; then
  "$ROOT/Scripts/package.sh" "$VERSION"
fi
[ -f "$DMG" ] || { echo "找不到产物 $DMG" >&2; exit 1; }
exec node "$CLI" release --app wiredeck --version "$VERSION" --code "$CODE" \
  --file "$DMG" --platform darwin --arch arm64 --format dmg --min-os 12.0 \
  --notes "WireDeck $VERSION" ${PASSTHRU[@]+"${PASSTHRU[@]}"}
