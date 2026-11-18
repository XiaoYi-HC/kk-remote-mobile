import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/utils/json_utils.dart';
import '../../../data/models/remote.dart';

/// WebRTC 连接封装：SDP/ICE、视频渲染与 control/file/chat/clipboard/stats/meta 通道。
/// DataChannel 标签与 docs/signaling-protocol.md 保持一致。
class PeerConnectionManager {
  PeerConnectionManager({
    required this.iceServers,
    this.onConnectionStateChanged,
    this.onIceStateChanged,
  });

  final List<Map<String, dynamic>> iceServers;
  final void Function(RTCPeerConnectionState state)? onConnectionStateChanged;
  final void Function(RTCIceConnectionState state)? onIceStateChanged;

  RTCPeerConnection? _pc;
  RTCVideoRenderer? _renderer;
  final Map<String, RTCDataChannel> _channels = {};
  final List<Map<String, dynamic>> _controlQueue = [];
  final List<RTCIceCandidate> _pendingIce = [];
  bool _remoteDescriptionSet = false;
  bool _disposed = false;
  Timer? _statsTimer;

  final StreamController<Map<String, dynamic>> _control =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _file =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _chat =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _clipboard =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<TransportInfo> _stats =
      StreamController<TransportInfo>.broadcast();
  final StreamController<Map<String, dynamic>> _meta =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionLog =
      StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get controlMessages => _control.stream;
  Stream<Map<String, dynamic>> get fileMessages => _file.stream;
  Stream<Map<String, dynamic>> get chatMessages => _chat.stream;
  Stream<Map<String, dynamic>> get clipboardMessages => _clipboard.stream;
  Stream<TransportInfo> get statsStream => _stats.stream;
  Stream<Map<String, dynamic>> get metaMessages => _meta.stream;
  Stream<String> get connectionLog => _connectionLog.stream;

  RTCVideoRenderer? get renderer => _renderer;
  RTCPeerConnection? get peerConnection => _pc;
  bool get isConnected => _pc != null;
  bool get controlReady => _channels['control']?.state == RTCDataChannelState.RTCDataChannelOpen;
  bool get fileReady => _channels['file']?.state == RTCDataChannelState.RTCDataChannelOpen;

  Future<RTCVideoRenderer> initRenderer() async {
    if (_renderer != null) return _renderer!;
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    _renderer = renderer;
    return renderer;
  }

  Future<void> initialize() async {
    if (_pc != null) return;
    final config = <String, dynamic>{
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };
    final pc = await createPeerConnection(config, {
      'mandatory': <String, dynamic>{},
      'optional': <Map<String, dynamic>>[
        {'DtlsSrtpKeyAgreement': true},
      ],
    });
    _pc = pc;
    await initRenderer();

    // 主控端只接收画面，必须先声明 recvonly 的视频 transceiver，
    // 否则 offer 中没有视频 m-line，被控端的视频轨道不会出现在 answer 里，表现为能看到界面但没有画面。
    try {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      // 同时声明音频 recvonly，否则 answer 里不会出现音频 m-line，
      // 被控端即使采集了系统声音也无法下发给手机。
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('addTransceiver failed: $error');
    }

    pc.onIceCandidate = (candidate) {
      onIceCandidate?.call(candidate);
    };
    pc.onIceConnectionState = (state) {
      onIceStateChanged?.call(state);
      _log('ICE: ${state.name}');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _log('ICE 连接失败');
      }
    };
    pc.onConnectionState = (state) {
      onConnectionStateChanged?.call(state);
      _log('连接状态: ${state.name}');
    };
    pc.onTrack = (event) {
      // 只把视频流交给渲染器，音频/摄像头等其它轨道不能覆盖画面。
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        _renderer?.srcObject = event.streams.first;
      }
      try {
        _meta.add({
          't': 'track.added',
          'kind': event.track.kind,
          'id': event.track.id,
        });
      } catch (_) {}
    };
    pc.onAddStream = (stream) {
      if (stream.getVideoTracks().isNotEmpty) {
        _renderer?.srcObject = stream;
      }
    };
    pc.onDataChannel = (channel) {
      _bindChannel(channel);
    };

    await _createDataChannel('control');
    await _createDataChannel('file');
    await _createDataChannel('chat');
    await _createDataChannel('clipboard');
    await _createDataChannel('stats');
    await _createDataChannel('meta');
    _startStatsPolling();
  }

  void Function(RTCIceCandidate candidate)? onIceCandidate;

  Future<void> _createDataChannel(String label) async {
    final pc = _pc;
    if (pc == null) return;
    final init = RTCDataChannelInit()..ordered = true;
    if (label == 'stats') init.maxRetransmits = 0;
    final channel = await pc.createDataChannel(label, init);
    _bindChannel(channel);
  }

  void _bindChannel(RTCDataChannel channel) {
    _channels[channel.label ?? ''] = channel;
    channel.onDataChannelState = (state) {
      _log('DataChannel ${channel.label}: ${state.name}');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _flushControlQueue();
      }
    };
    channel.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) {
        _file.add({'t': 'binary', 'data': message.binary});
        return;
      }
      try {
        final map = asMap(jsonDecode(message.text));
        switch (channel.label) {
          case 'control':
            _control.add(map);
            break;
          case 'file':
            _file.add(map);
            break;
          case 'chat':
            _chat.add(map);
            break;
          case 'clipboard':
            _clipboard.add(map);
            break;
          case 'stats':
            _stats.add(TransportInfo.fromJson(map));
            break;
          case 'meta':
            _meta.add(map);
            break;
        }
      } catch (error) {
        if (kDebugMode) debugPrint('DataChannel ${channel.label} parse error: $error');
      }
    };
  }

  Future<String> createOffer() async {
    final pc = _pc;
    if (pc == null) throw StateError('PeerConnection 未初始化');
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    return offer.sdp ?? '';
  }

  Future<String> handleOffer(String sdp) async {
    final pc = _pc;
    if (pc == null) throw StateError('PeerConnection 未初始化');
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    _remoteDescriptionSet = true;
    await _flushPendingIce();
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    return answer.sdp ?? '';
  }

  Future<void> handleAnswer(String sdp) async {
    final pc = _pc;
    if (pc == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    _remoteDescriptionSet = true;
    await _flushPendingIce();
  }

  Future<void> addIceCandidate({
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) async {
    if (candidate.isEmpty) return;
    // iOS 原生实现会对 sdpMid 调用 stdString，传入 null(NSNull) 会直接崩溃，
    // 部分候选（尤其是被控端 webrtc-rs 发出的）可能缺少 sdpMid/sdpMLineIndex，这里统一补默认值。
    final mid = (sdpMid == null || sdpMid.isEmpty) ? '0' : sdpMid;
    final mLineIndex = sdpMLineIndex ?? 0;
    final ice = RTCIceCandidate(candidate, mid, mLineIndex);
    // 远端描述尚未设置时先缓存，否则 addCandidate 会抛错并永久丢失该候选。
    if (!_remoteDescriptionSet) {
      _pendingIce.add(ice);
      return;
    }
    await _addIceSafely(ice);
  }

  Future<void> _flushPendingIce() async {
    if (_pendingIce.isEmpty) return;
    final pending = List<RTCIceCandidate>.from(_pendingIce);
    _pendingIce.clear();
    for (final ice in pending) {
      await _addIceSafely(ice);
    }
  }

  Future<void> _addIceSafely(RTCIceCandidate ice) async {
    try {
      await _pc?.addCandidate(ice);
    } catch (error) {
      if (kDebugMode) debugPrint('addCandidate failed: $error');
    }
  }

  void _log(String message) {
    if (_disposed) return;
    try {
      _connectionLog.add(message);
    } catch (_) {}
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) => pollStats());
  }

  int _lastBytesReceived = 0;
  int _lastBytesSent = 0;

  Future<void> pollStats() async {
    if (_disposed) return;
    final pc = _pc;
    if (pc == null) return;
    try {
      final reports = await pc.getStats();
      int rttMs = 0;
      double lossRate = 0;
      int bitrateKbps = 0;
      int fps = 0;
      int bytesReceived = _lastBytesReceived;
      int bytesSent = _lastBytesSent;
      String remoteAddress = '';
      String candidateType = '';
      String transport = '';
      for (final report in reports) {
        final values = report.values;
        if (report.type == 'candidate-pair' && values['state'] == 'succeeded') {
          final rtt = values['currentRoundTripTime'];
          if (rtt is num) rttMs = (rtt * 1000).round();
          final availableIncoming = values['availableIncomingBitrate'];
          if (availableIncoming is num) {
            bitrateKbps = (availableIncoming / 1000).round();
          }
          final localCandidateId = asString(values['localCandidateId']);
          final remoteCandidateId = asString(values['remoteCandidateId']);
          for (final candidate in reports) {
            if (candidate.id == localCandidateId || candidate.id == remoteCandidateId) {
              candidateType = asString(candidate.values['candidateType'], fallback: candidateType);
              remoteAddress = asString(candidate.values['address'], fallback: remoteAddress);
            }
          }
        }
        if (report.type == 'inbound-rtp') {
          final kind = asString(values['kind']);
          if (kind == 'video') {
            final packetsLost = asInt(values['packetsLost']);
            final packetsReceived = asInt(values['packetsReceived']);
            final total = packetsLost + packetsReceived;
            if (total > 0) lossRate = (packetsLost / total).clamp(0.0, 1.0).toDouble();
            fps = asInt(values['framesPerSecond']);
          }
          final incoming = asInt(values['bytesReceived']);
          if (incoming > 0) bytesReceived = incoming;
        }
        if (report.type == 'outbound-rtp') {
          final outgoing = asInt(values['bytesSent']);
          if (outgoing > 0) bytesSent = outgoing;
        }
        if (report.type == 'transport' && values['selectedCandidatePairId'] != null) {
          final dtls = asString(values['dtlsState']);
          if (dtls.isNotEmpty) transport = dtls;
        }
      }
      final deltaBytes = bytesReceived - _lastBytesReceived;
      final deltaSent = bytesSent - _lastBytesSent;
      if (deltaBytes > 0) {
        final computed = (deltaBytes * 8 / 1000).round();
        if (computed > bitrateKbps) bitrateKbps = computed;
      }
      _lastBytesReceived = bytesReceived;
      _lastBytesSent = bytesSent;
      final p2p = candidateType == 'host' || candidateType == 'srflx';
      if (_disposed) return;
      try {
        _stats.add(TransportInfo(
          transport: p2p ? 'p2p' : (candidateType == 'relay' ? 'relay' : ''),
          candidateType: candidateType,
          rttMs: rttMs,
          lossRate: lossRate,
          bitrateKbps: bitrateKbps,
          fps: fps,
          downBw: (deltaBytes * 8 / 1000).round().clamp(0, 1 << 31).toInt(),
          upBw: (deltaSent * 8 / 1000).round().clamp(0, 1 << 31).toInt(),
          remoteAddress: remoteAddress,
          connectionState: transport,
        ));
      } catch (_) {}
    } catch (error) {
      if (kDebugMode) debugPrint('pollStats error: $error');
    }
  }

  Future<void> setSpeakerphoneOn(bool enabled) async {
    try {
      await Helper.setSpeakerphoneOn(enabled);
    } catch (_) {
      // 部分平台不支持该能力。
    }
  }

  Future<void> setRemoteAudioEnabled(bool enabled) async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final receivers = await pc.getReceivers();
      for (final receiver in receivers) {
        final track = receiver.track;
        if (track != null && track.kind == 'audio') {
          track.enabled = enabled;
        }
      }
    } catch (error) {
      if (kDebugMode) debugPrint('toggle audio failed: $error');
    }
  }

  void _flushControlQueue() {
    if (!controlReady) return;
    final pending = List<Map<String, dynamic>>.from(_controlQueue);
    _controlQueue.clear();
    for (final event in pending) {
      _sendOn('control', event);
    }
  }

  void sendControl(Map<String, dynamic> event) {
    if (!controlReady) {
      if (_controlQueue.length < 128) _controlQueue.add(event);
      return;
    }
    _sendOn('control', event);
  }

  bool sendFile(Map<String, dynamic> event) => _sendOn('file', event);

  void sendChat(Map<String, dynamic> event) => _sendOn('chat', event);

  void sendClipboard(Map<String, dynamic> event) => _sendOn('clipboard', event);

  void sendStats(Map<String, dynamic> event) => _sendOn('stats', event);

  void sendMeta(Map<String, dynamic> event) => _sendOn('meta', event);

  int get fileBufferedAmount => _channels['file']?.bufferedAmount ?? 0;

  bool _sendOn(String label, Map<String, dynamic> event) {
    final channel = _channels[label];
    if (channel == null || channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      return false;
    }
    try {
      channel.send(RTCDataChannelMessage(jsonEncode(event)));
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('send $label failed: $error');
      return false;
    }
  }

  void moveMouse(double x, double y) {
    sendControl({'t': 'mouse.move', 'x': x.clamp(0, 1), 'y': y.clamp(0, 1)});
  }

  void mouseButton(String button, bool down, double x, double y) {
    sendControl({
      't': 'mouse.button',
      'button': button,
      'down': down,
      'x': x.clamp(0, 1),
      'y': y.clamp(0, 1),
    });
  }

  void wheel(int delta) {
    sendControl({'t': 'wheel', 'delta': delta});
  }

  void key(String code, bool down, {List<String> modifiers = const []}) {
    sendControl({
      't': 'key',
      'code': code,
      'down': down,
      'modifiers': modifiers,
    });
  }

  void keyCombo(List<String> keys) {
    sendControl({'t': 'key.combo', 'keys': keys});
  }

  void text(String value) {
    sendControl({'t': 'text', 'value': value});
  }

  void systemAction(String action) {
    sendControl({'t': 'system.action', 'action': action});
  }

  void clipboard(String kind, String content) {
    sendControl({'t': 'clipboard', 'kind': kind, 'content': content});
  }

  Future<void> dispose() async {
    _disposed = true;
    _statsTimer?.cancel();
    _statsTimer = null;
    final pc = _pc;
    if (pc != null) {
      // 先摘掉原生回调，避免释放过程中仍向已关闭的 StreamController 投递事件。
      try {
        pc.onIceCandidate = null;
        pc.onIceConnectionState = null;
        pc.onConnectionState = null;
        pc.onTrack = null;
        pc.onAddStream = null;
        pc.onDataChannel = null;
      } catch (_) {}
    }
    for (final channel in _channels.values) {
      try {
        channel.onDataChannelState = null;
        channel.onMessage = null;
        await channel.close();
      } catch (_) {}
    }
    _channels.clear();
    try {
      await pc?.close();
    } catch (_) {}
    _pc = null;
    try {
      await _renderer?.dispose();
    } catch (_) {}
    _renderer = null;
    await _control.close();
    await _file.close();
    await _chat.close();
    await _clipboard.close();
    await _stats.close();
    await _meta.close();
    await _connectionLog.close();
  }
}
