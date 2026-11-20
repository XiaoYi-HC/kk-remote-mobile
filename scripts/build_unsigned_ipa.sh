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

echo "== CocoaPods 安装 =="
( cd ios && pod install --repo-update )

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
