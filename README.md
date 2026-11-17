# KK远程 Flutter 移动主控端

Android / iOS 主控端，ApplicationId / BundleId：`com.kk.remote`。

## 运行

```bash
cd mobile
flutter pub get
flutter analyze
flutter run
```

构建：

```bash
flutter build apk --release
flutter build ios --release --no-codesign
```

## 配置

- 默认 API：`http://127.0.0.1:8080/api/v1`
- 默认信令：`ws://127.0.0.1:8081/ws/signaling`
- 启动后请求 `/api/v1/client/config/bootstrap`，自动使用服务端下发的 `apiBaseUrl`、`signalingUrl`、ICE Servers 与功能开关。
- 真机调试时请在移动端“设置 → 连接设置”中改为局域网 IP，或通过服务端公网地址访问。
- 客服 WebSocket 由 API 源推导为 `ws://<api-host>/ws/support`。

## 目录

```
lib/
├─ core/       主题、常量、网络、存储、平台通道
├─ data/       API、WebSocket、模型
├─ features/   auth / devices / remote / files / settings / support / account
├─ routing/    路由与页面注册
├─ state/      Provider 状态
└─ widgets/    共享组件（加载动画、P2P 标签、隐私弹窗等）
```

远程画面使用 `flutter_webrtc`，DataChannel 标签与 `docs/signaling-protocol.md` 一致：`control/file/chat/clipboard/stats/meta`。

## 已知限制

- 已执行 `flutter analyze`（Flutter 3.24.5）通过；未构建 APK/iOS，未做真机联调。
- 原生推流/编解码、Android Gradle / iOS Xcode 构建、真机权限与后台策略需在目标环境验证。
- APNs/FCM、真实投屏、录制、PiP、手柄/陀螺仪等系统能力保留平台通道入口，需真机联调。
- OAuth 深链回调、release 签名、商店素材与隐私清单需发布前补齐。
- 文件传输支持 `fs.list / fs.download / fs.upload.*` JSON 协议，以及二进制分块协议；被控 Agent 已同时支持两种协议。
- API 会话数值 ID 与信令字符串 sessionId 的映射在部分归档/迁移场景仍需补强。

## 品牌

图标来自 `assets/branding/`，已复制到 Android mipmap、iOS AppIcon 与 `assets/images/logo.png`；产品名统一“KK远程”。
