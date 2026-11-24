#!/usr/bin/env bash
# 在 macOS 上构建未签名 IPA（无需 Apple 开发者账号）
# 用法：在 mobile 目录执行  bash scripts/build_unsigned_ipa.sh
set -euo pipefail

cd "$(dirname "$0")/.."
echo "== 工作目录: $(pwd) =="

command -v flutter >/dev/null || { echo "未找到 flutter，请先安装 Flutter SDK"; exit 1; }
flutter --version

# 服务端地址：默认指向生产环境，可通过环境变量覆盖
API_BASE_URL="${API_BASE_URL:-https://shop1.new.tg/api/v1}"
SIGNALING_URL="${SIGNALING_URL:-wss://shop1.new.tg/ws/signaling}"
echo "== API_BASE_URL: $API_BASE_URL =="
echo "== SIGNALING_URL: $SIGNALING_URL =="

echo "== 拉取依赖 =="
flutter pub get

echo "== 应用 iOS 屏幕共享 TCP 补丁 =="
python3 scripts/patch_screen_capture_tcp.py

echo "== CocoaPods 安装 =="
( cd ios && pod install --repo-update )

echo "== 配置 iOS 屏幕共享扩展 =="
if [ -f scripts/add_broadcast_extension.rb ]; then
  if command -v ruby >/dev/null 2>&1; then
    if ! ruby -e "require 'xcodeproj'" >/dev/null 2>&1; then
      gem install xcodeproj --no-document || true
    fi
    ruby scripts/add_broadcast_extension.rb || echo "警告：屏幕共享扩展配置失败，iOS 端将无法共享屏幕"
  else
    echo "警告：未找到 ruby，跳过屏幕共享扩展配置"
  fi
fi

echo "== 编译 iOS Release（不签名）=="
flutter build ios --release --no-codesign \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=SIGNALING_URL="$SIGNALING_URL"

APP="build/ios/iphoneos/Runner.app"
[ -d "$APP" ] || { echo "编译产物不存在: $APP"; exit 1; }

echo "== 打包为 IPA =="
rm -rf build/ipa
mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/
( cd build/ipa && zip -qry ../KKRemote-unsigned.ipa Payload )

ls -lh build/KKRemote-unsigned.ipa
echo "完成：KKRemote-unsigned.ipa（未签名，安装到真机需用 AltStore/Sideloadly 等工具重签）"
