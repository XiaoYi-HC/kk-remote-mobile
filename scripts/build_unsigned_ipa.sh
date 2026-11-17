#!/usr/bin/env bash
# 在 macOS 上构建未签名 IPA（无需 Apple 开发者账号）
# 用法：在 mobile 目录执行  bash scripts/build_unsigned_ipa.sh
set -euo pipefail

cd "$(dirname "$0")/.."
echo "== 工作目录: $(pwd) =="

command -v flutter >/dev/null || { echo "未找到 flutter，请先安装 Flutter SDK"; exit 1; }
flutter --version

echo "== 拉取依赖 =="
flutter pub get

echo "== CocoaPods 安装 =="
( cd ios && pod install --repo-update )

echo "== 编译 iOS Release（不签名）=="
flutter build ios --release --no-codesign

APP="build/ios/iphoneos/Runner.app"
[ -d "$APP" ] || { echo "编译产物不存在: $APP"; exit 1; }

echo "== 打包为 IPA =="
rm -rf build/ipa
mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/
( cd build/ipa && zip -qry ../KKRemote-unsigned.ipa Payload )

ls -lh build/KKRemote-unsigned.ipa
echo "完成：mobile/build/KKRemote-unsigned.ipa（未签名，安装到真机需用 AltStore/Sideloadly 等工具重签）"
