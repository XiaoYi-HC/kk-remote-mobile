import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/utils/json_utils.dart';

class SignalingMessage {
  const SignalingMessage({
    required this.type,
    this.data = const {},
    this.sessionId = '',
    this.code = 0,
    this.message = '',
    this.seq = 0,
    this.ts,
  });

  final String type;
  final Map<String, dynamic> data;
  final String sessionId;
  final int code;
  final String message;
  final int seq;
  final DateTime? ts;

  String? get failureReason => asStringOrNull(data['failureReason']);
  String? get stage => asStringOrNull(data['stage']);

  /// 兼容服务端 message 与 data.message 两种错误结构。
  String get displayMessage {
    if (message.isNotEmpty) return message;
    return asString(data['message']);
  }
}

class SignalingClient {
  SignalingClient();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  int _seq = 0;
  String _sessionId = '';
  bool _disposed = false;

  final StreamController<SignalingMessage> _events =
      StreamController<SignalingMessage>.broadcast();

  Stream<SignalingMessage> get events => _events.stream;
  bool get isConnected => _channel != null;
  String get sessionId => _sessionId;

  /// controller 使用登录 accessToken；游客 token 同样可用。
  Future<void> connect({
    required String signalingUrl,
    required String token,
    String role = 'controller',
    String platform = 'android',
    String version = '1.0.0',
  }) async {
    await close();
    if (_disposed) return;
    final base = Uri.parse(signalingUrl);
    final uri = base.replace(
      path: base.path.isEmpty ? '/ws/signaling' : base.path,
      queryParameters: {
        ...base.queryParameters,
        'role': role,
        'token': token,
        'platform': platform,
        'version': version,
      },
    );
    _channel = WebSocketChannel.connect(uri);
    await _channel!.ready;
    _subscription = _channel!.stream.listen(
      _handleRaw,
      onError: (Object error, StackTrace stack) {
        _events.add(SignalingMessage(type: 'socket.error', message: error.toString()));
      },
      onDone: () {
        _events.add(const SignalingMessage(type: 'socket.closed', message: '信令连接已断开'));
      },
      cancelOnError: false,
    );
    _startHeartbeat();
  }

  void _handleRaw(dynamic raw) {
    try {
      final map = asMap(jsonDecode(raw.toString()));
      final type = asString(map['type']);
      if (type.isEmpty) return;
      final sessionId = asString(map['sessionId']);
      if (sessionId.isNotEmpty) _sessionId = sessionId;
      _events.add(SignalingMessage(
        type: type,
        data: asMap(map['data']),
        sessionId: sessionId,
        code: asInt(map['code']),
        message: asString(map['message']),
        seq: asInt(map['seq']),
        ts: DateTime.tryParse(asString(map['ts'])) ??
            DateTime.fromMillisecondsSinceEpoch(asInt(map['ts'])),
      ));
    } catch (error) {
      if (kDebugMode) debugPrint('signaling parse error: $error');
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      send('ping');
    });
  }

  void send(String type, {Map<String, dynamic>? data, String? sessionId}) {
    final channel = _channel;
    if (channel == null) return;
    final envelope = <String, dynamic>{
      'v': 1,
      'type': type,
      'seq': ++_seq,
      'ts': DateTime.now().millisecondsSinceEpoch,
      if ((sessionId ?? _sessionId).isNotEmpty) 'sessionId': sessionId ?? _sessionId,
      if (data != null) 'data': data,
    };
    try {
      channel.sink.add(jsonEncode(envelope));
    } catch (error) {
      if (kDebugMode) debugPrint('signaling send error: $error');
    }
  }

  void connectRequest({
    required String targetDeviceCode,
    String? verifyCode,
    String? password,
    String qualityPreset = 'hd',
    String controllerDeviceName = 'KK远程手机',
    String controllerPlatform = 'android',
    String mode = 'control',
  }) {
    send('connect.request', data: {
      'targetDeviceCode': targetDeviceCode.trim(),
      if (verifyCode != null && verifyCode.isNotEmpty) 'verifyCode': verifyCode,
      if (password != null && password.isNotEmpty) 'password': password,
      'qualityPreset': qualityPreset,
      'controllerDeviceName': controllerDeviceName,
      'controllerPlatform': controllerPlatform,
      'mode': mode,
    });
  }

  void sendOffer(String sdp, {String? sessionId}) {
    send('webrtc.offer', data: {'sdp': sdp, 'type': 'offer'}, sessionId: sessionId);
  }

  void sendAnswer(String sdp, {String? sessionId}) {
    send('webrtc.answer', data: {'sdp': sdp, 'type': 'answer'}, sessionId: sessionId);
  }

  void sendIce({
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
    String? candidateType,
    String? sessionId,
  }) {
    send('webrtc.ice', data: {
      'candidate': candidate,
      if (sdpMid != null) 'sdpMid': sdpMid,
      if (sdpMLineIndex != null) 'sdpMLineIndex': sdpMLineIndex,
      if (candidateType != null) 'candidateType': candidateType,
    }, sessionId: sessionId);
  }

  void sendSessionState({
    required String stage,
    String? transport,
    String? candidateType,
    String? iceState,
    String? failureReason,
    int rttMs = 0,
    double lossRate = 0,
    int bitrateKbps = 0,
    int fps = 0,
    int upBwKbps = 0,
    int downBwKbps = 0,
    bool privacyBlackScreen = false,
  }) {
    send('session.state', data: {
      'stage': stage,
      if (transport != null) 'transport': transport,
      if (candidateType != null) 'candidateType': candidateType,
      if (iceState != null) 'iceState': iceState,
      if (failureReason != null) 'failureReason': failureReason,
      'rttMs': rttMs,
      'lossRate': lossRate,
      'bitrateKbps': bitrateKbps,
      'fps': fps,
      'upBwKbps': upBwKbps,
      'downBwKbps': downBwKbps,
      'privacyBlackScreen': privacyBlackScreen,
    });
  }

  void sendPrivacy(bool enabled) {
    send('privacy.sync', data: {'enabled': enabled});
  }

  void sendControlRequest({required String action, Map<String, dynamic>? payload}) {
    send('control.request', data: {
      'action': action,
      if (payload != null) 'payload': payload,
    });
  }

  void closeSession({String reason = 'user_closed'}) {
    send('session.close', data: {'reason': reason});
  }

  Future<void> close() async {
    _heartbeat?.cancel();
    _heartbeat = null;
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
    _disposed = true;
    await close();
    await _events.close();
  }
}
