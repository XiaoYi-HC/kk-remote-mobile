import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/devices/state/connect_args.dart';
import 'native_bridge.dart';

class OAuthCallback {
  const OAuthCallback({required this.code, required this.state, this.error = ''});

  final String code;
  final String state;
  final String error;
}

/// 统一处理 kkremote:// 深链：连接、分享与第三方登录回调。
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  GoRouter? _router;
  String? _pendingLink;
  Completer<OAuthCallback?>? _oauthCompleter;
  OAuthCallback? _lastOAuth;
  DateTime? _lastOAuthAt;

  Future<void> init() async {
    NativeBridge.instance.setDeepLinkHandler(_handle);
    final initial = await NativeBridge.instance.getInitialLink();
    if (initial != null && initial.isNotEmpty) _handle(initial);
  }

  void attachRouter(GoRouter router) {
    _router = router;
    final pending = _pendingLink;
    _pendingLink = null;
    if (pending != null) _handle(pending);
  }

  void _handle(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'kkremote') return;
    switch (uri.host) {
      case 'connect':
        final code = uri.queryParameters['deviceCode'] ??
            uri.queryParameters['code'] ??
            '';
        if (code.isEmpty) return;
        final router = _router;
        if (router == null) {
          _pendingLink = raw;
          return;
        }
        // 冷启动时路由可能尚未挂载，延迟到首帧后再导航。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.push(
            '/connect',
            extra: ConnectArgs(
              deviceCode: code,
              deviceName: uri.queryParameters['deviceName'] ??
                  uri.queryParameters['name'] ??
                  '',
              showBindOption: true,
            ),
          );
        });
        break;
      case 'oauth':
        final isCallback = uri.pathSegments.isEmpty ||
            uri.pathSegments.first == 'callback';
        if (!isCallback) return;
        final completer = _oauthCompleter;
        _oauthCompleter = null;
        final callback = OAuthCallback(
          code: uri.queryParameters['code'] ?? '',
          state: uri.queryParameters['state'] ?? '',
          error: uri.queryParameters['error'] ?? '',
        );
        // 冷启动导致登录页尚未开始等待时，暂存回调供页面稍后取用。
        _lastOAuth = callback;
        _lastOAuthAt = DateTime.now();
        if (completer != null && !completer.isCompleted) {
          completer.complete(callback);
        }
        break;
      case 'share':
        // 分享链接当前落地到首页，由用户手动选择设备。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _router?.go('/home');
        });
        break;
      default:
        break;
    }
  }

  Future<OAuthCallback?> waitForOAuth({
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final cached = _lastOAuth;
    final cachedAt = _lastOAuthAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(minutes: 2)) {
      _lastOAuth = null;
      _lastOAuthAt = null;
      return cached;
    }
    final completer = Completer<OAuthCallback?>();
    _oauthCompleter = completer;
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      return null;
    } finally {
      if (identical(_oauthCompleter, completer)) {
        _oauthCompleter = null;
      }
    }
  }

  void cancelOAuth() {
    _lastOAuth = null;
    _lastOAuthAt = null;
    final completer = _oauthCompleter;
    _oauthCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
  }
}
