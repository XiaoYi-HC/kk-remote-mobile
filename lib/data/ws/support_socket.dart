import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/utils/json_utils.dart';
import '../models/support.dart';

/// 客服 WebSocket：/ws/support?token=<accessToken>
class SupportSocket {
  SupportSocket();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;

  final StreamController<SupportSocketEvent> _events =
      StreamController<SupportSocketEvent>.broadcast();

  Stream<SupportSocketEvent> get events => _events.stream;
  bool get isConnected => _channel != null;

  Future<void> connect({
    required String wsBaseUrl,
    required String token,
  }) async {
    await close();
    final base = Uri.parse(wsBaseUrl);
    final uri = base.replace(
      path: '/ws/support',
      queryParameters: {'token': token},
    );
    _channel = WebSocketChannel.connect(uri);
    final channel = _channel!;
    try {
      await channel.ready;
    } catch (error) {
      if (identical(_channel, channel)) _channel = null;
      rethrow;
    }
    // 等待 ready 期间可能被 close()/新的 connect() 替换，此时不能继续绑定旧通道。
    if (!identical(_channel, channel)) return;
    _subscription = channel.stream.listen(
      (raw) {
        try {
          final map = asMap(jsonDecode(raw.toString()));
          _events.add(SupportSocketEvent.fromJson(map));
        } catch (error) {
          if (kDebugMode) debugPrint('support parse error: $error');
        }
      },
      onError: (Object error, StackTrace stack) {
        _events.add(SupportSocketEvent(type: 'support.disconnected', data: {'message': error.toString()}));
      },
      onDone: () {
        // 连接断开不等于客服关闭会话，交给上层决定是否重连。
        _events.add(const SupportSocketEvent(type: 'support.disconnected'));
      },
      cancelOnError: false,
    );
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _send({'type': 'ping'});
    });
  }

  bool sendMessage({
    required int conversationId,
    required String contentType,
    required String content,
    int attachmentId = 0,
  }) {
    return _send({
      'type': 'support.message',
      'data': {
        'conversationId': conversationId,
        'contentType': contentType,
        'content': content,
        'attachmentId': attachmentId,
      },
    });
  }

  bool sendTyping(int conversationId) {
    return _send({
      'type': 'support.typing',
      'data': {'conversationId': conversationId},
    });
  }

  bool markRead(int conversationId) {
    return _send({
      'type': 'support.read',
      'data': {'conversationId': conversationId},
    });
  }

  bool _send(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return false;
    try {
      channel.sink.add(jsonEncode(payload));
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('support send error: $error');
      return false;
    }
  }

  Future<void> close() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // 忽略关闭异常。
    }
    _channel = null;
  }

  Future<void> dispose() async {
    await close();
    await _events.close();
  }
}
