#!/bin/bash
# 构建 WireDeck → dmg → 上传并发布到 VaKao 软件中心
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="${HUB_CLI:-/Users/woyuxiaji/Rouarn/AliyunCloud/vakao-hub/tools/hub-cli.mjs}"
VERSION=$(python3 -c "import json;print(json.load(open('$ROOT/wails.json'))['info']['productVersion'])")
CODE=$(echo "$VERSION" | awk -F. '{printf "%d", $1*100+$2*10+$3}')
DMG="$ROOT/build/WireDeck-${VERSION}.dmg"
if [ "${1:-}" != "--no-build" ]; then
  "$ROOT/Scripts/package.sh" "$VERSION"
fi
[ -f "$DMG" ] || { echo "找不到产物 $DMG" >&2; exit 1; }
exec node "$CLI" release --app wiredeck --version "$VERSION" --code "$CODE" \
  --file "$DMG" --platform darwin --arch arm64 --format dmg --min-os 12.0 \
  --notes "WireDeck $VERSION" "$@"
