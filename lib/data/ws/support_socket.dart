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
    await _channel!.ready;
    _subscription = _channel!.stream.listen(
      (raw) {
        try {
          final map = asMap(jsonDecode(raw.toString()));
          _events.add(SupportSocketEvent.fromJson(map));
        } catch (error) {
          if (kDebugMode) debugPrint('support parse error: $error');
        }
      },
      onError: (Object error, StackTrace stack) {
        _events.add(SupportSocketEvent(type: 'support.error', data: {'message': error.toString()}));
      },
      onDone: () {
        _events.add(const SupportSocketEvent(type: 'support.closed'));
      },
      cancelOnError: false,
    );
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _send({'type': 'ping'});
    });
  }

  void sendMessage({
    required int conversationId,
    required String contentType,
    required String content,
    int attachmentId = 0,
  }) {
    _send({
      'type': 'support.message',
      'data': {
        'conversationId': conversationId,
        'contentType': contentType,
        'content': content,
        'attachmentId': attachmentId,
      },
    });
  }

  void sendTyping(int conversationId) {
    _send({
      'type': 'support.typing',
      'data': {'conversationId': conversationId},
    });
  }

  void markRead(int conversationId) {
    _send({
      'type': 'support.read',
      'data': {'conversationId': conversationId},
    });
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (error) {
      if (kDebugMode) debugPrint('support send error: $error');
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
