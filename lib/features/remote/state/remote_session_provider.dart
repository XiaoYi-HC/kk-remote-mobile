import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/json_utils.dart';
import '../../../data/models/common.dart';
import '../../../data/models/remote.dart';
import '../../../data/ws/signaling_client.dart';
import '../../../state/app_services.dart';
import '../../../state/settings_provider.dart';
import '../services/peer_connection_manager.dart';
import 'remote_args.dart';

/// 远程会话状态机：信令、PeerConnection、输入、隐私、画面指标与重连。
class RemoteSessionProvider extends ChangeNotifier {
  RemoteSessionProvider({
    required this.services,
    required this.settings,
    required this.args,
    required List<IceServerConfig> iceServers,
  }) : _iceServers = List<IceServerConfig>.from(iceServers) {
    castMode = args.castMode;
    trackballMode = settings.trackballMode;
    viewOnly = args.mode == 'view';
    audioEnabled = settings.audioEnabled;
    cursorHidden = settings.hideCursor;
    if (!settings.allowRelay) {
      // 关闭"允许中继"后不再向 ICE 注入 TURN 节点，避免实际仍走中继。
      _iceServers = _iceServers
          .where((server) => !server.urls.any(
                (url) => url.trim().toLowerCase().startsWith('turn'),
              ))
          .toList();
    }
  }

  final AppServices services;
  final SettingsProvider settings;
  final RemoteArgs args;
  List<IceServerConfig> _iceServers;

  final SignalingClient _signaling = SignalingClient();
  PeerConnectionManager? _peer;
  RTCVideoRenderer? renderer;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _durationTimer;
  Timer? _reconnectTimer;
  Timer? _uiTicker;
  int _reconnectAttempts = 0;
  int _peerRetries = 0;
  final Set<String> _heldKeys = <String>{};
  bool _starting = false;
  bool _closedByUser = false;
  bool _disposed = false;
  int _trafficBytes = 0;
  DateTime _lastTrafficAt = DateTime.now();
  DateTime? _lastQualityAdjustAt;

  RemoteStage stage = RemoteStage.matching;
  RemoteFailure? failure;
  TransportInfo transport = const TransportInfo();
  bool privacyBlackScreen = false;
  bool audioEnabled = true;
  bool microphoneEnabled = false;
  bool viewOnly = false;
  bool antiTouch = false;
  bool trackballMode = false;
  bool castMode = false;
  bool castingActive = false;
  bool pipActive = false;
  bool recording = false;
  bool cursorHidden = false;
  String sessionId = '';
  String connectionNotice = '';
  Duration elapsed = Duration.zero;
  List<DisplayInfo> displays = const [];
  String activeDisplayId = '';
  Map<String, dynamic> cameraState = const {};
  final List<Map<String, dynamic>> chatMessages = [];
  DateTime? startedAt;

  String get stageText {
    switch (stage) {
      case RemoteStage.idle:
      case RemoteStage.matching:
        return '正在匹配设备';
      case RemoteStage.waitingConfirm:
        return '等待对方确认';
      case RemoteStage.iceChecking:
        return '正在建立加密通道';
      case RemoteStage.p2pConnected:
      case RemoteStage.relayConnected:
        return '画面传输中';
      case RemoteStage.failed:
        return failure?.message ?? '连接失败';
    }
  }

  int get stageStep {
    switch (stage) {
      case RemoteStage.idle:
      case RemoteStage.matching:
        return 0;
      case RemoteStage.waitingConfirm:
        return 1;
      case RemoteStage.iceChecking:
        return 2;
      case RemoteStage.p2pConnected:
      case RemoteStage.relayConnected:
        return 4;
      case RemoteStage.failed:
        return -1;
    }
  }

  bool get connected => stage.isConnected;
  bool get connecting => !connected && stage != RemoteStage.failed;
  bool get canForwardInput => connected && !viewOnly && !antiTouch;

  /// 媒体统计超过 6 秒未更新，用于回前台后的画面健康检查。
  bool get mediaStale =>
      connected && DateTime.now().difference(_lastTrafficAt) > const Duration(seconds: 6);
  int get trafficBytes => _trafficBytes;
  String get activeDisplayLabel {
    if (displays.isEmpty) return '显示器';
    for (final display in displays) {
      if (display.id == activeDisplayId) return display.label;
    }
    return displays.first.label;
  }

  PeerConnectionManager? get peer => _peer;

  /// 画面诊断：用于现场判断"没收到/没解码/没渲染"。
  Map<String, String> get videoDiagnostics {
    final info = <String, String>{
      'stage': stage.name,
      'renderer': '${renderer?.value.width ?? 0}x${renderer?.value.height ?? 0}',
      'fps': '${transport.fps}',
      'bitrate': '${transport.bitrateKbps} kbps',
      'rtt': '${transport.rttMs} ms',
      'loss': '${(transport.lossRate * 100).toStringAsFixed(1)}%',
    };
    final diagnostics = _peer?.videoDiagnostics;
    if (diagnostics != null) info.addAll(diagnostics);
    return info;
  }

  Future<void> start() async {
    if (_starting) return;
    _starting = true;
    _closedByUser = false;
    failure = null;
    stage = RemoteStage.matching;
    connectionNotice = '正在连接信令服务';
    elapsed = Duration.zero;
    startedAt = DateTime.now();
    _trafficBytes = 0;
    _lastTrafficAt = DateTime.now();
    notifyListeners();

    _subs.add(_signaling.events.listen((event) {
      _onSignalingEvent(event).catchError((Object error) {
        if (kDebugMode) debugPrint('signaling event failed: $error');
      });
    }));
    try {
      await _signaling.connect(
        signalingUrl: settings.resolvedSignalingUrl,
        token: services.api.token ?? '',
        role: 'controller',
        platform: Platform.isIOS ? 'ios' : 'android',
        version: AppConstants.appVersion,
      );
      connectionNotice = '正在请求连接';
      _signaling.connectRequest(
        targetDeviceCode: args.deviceCode,
        verifyCode: args.verifyCode,
        password: args.password,
        qualityPreset: settings.saveDataMode ? 'sd' : settings.qualityPreset,
        controllerDeviceName: Platform.isIOS ? 'KK远程 iPhone' : 'KK远程手机',
        controllerPlatform: Platform.isIOS ? 'ios' : 'android',
        mode: viewOnly ? 'view' : 'control',
      );
      _startTimers();
      if (Platform.isAndroid && settings.backgroundKeepAlive) {
        services.native.startRemoteForegroundService();
      }
    } catch (error) {
      _fail('network_unreachable', '无法连接信令服务：$error');
    } finally {
      _starting = false;
    }
  }

  void _startTimers() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (connected && startedAt != null) {
        elapsed = DateTime.now().difference(startedAt!);
        notifyListeners();
      }
    });
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (connected) {
        _signaling.sendSessionState(
          stage: stage == RemoteStage.relayConnected ? 'relay_connected' : 'p2p_connected',
          transport: transport.transport,
          candidateType: transport.candidateType,
          rttMs: transport.rttMs,
          lossRate: transport.lossRate,
          bitrateKbps: transport.bitrateKbps,
          fps: transport.fps,
          upBwKbps: transport.upBw,
          downBwKbps: transport.downBw,
          privacyBlackScreen: privacyBlackScreen,
        );
      }
    });
    if (settings.keepScreenOn) {
      WakelockPlus.enable();
    }
  }

  Future<void> _onSignalingEvent(SignalingMessage event) async {
    switch (event.type) {
      case 'auth.ok':
        connectionNotice = '信令已连接';
        break;
      case 'config.snapshot':
        final servers = asList(event.data['iceServers'])
            .map((item) => IceServerConfig.fromJson(asMap(item)))
            .where((item) => item.urls.isNotEmpty)
            .toList();
        if (servers.isNotEmpty && _peer == null) {
          _iceServers = servers;
        }
        break;
      case 'connect.result':
        await _handleConnectResult(event);
        break;
      case 'webrtc.answer':
        final sdp = asString(event.data['sdp']);
        if (sdp.isNotEmpty) {
          await _peer?.handleAnswer(sdp);
        }
        break;
      case 'webrtc.ice':
        await _peer?.addIceCandidate(
          candidate: asString(event.data['candidate']),
          sdpMid: asStringOrNull(event.data['sdpMid']),
          sdpMLineIndex: asIntOrNull(event.data['sdpMLineIndex']),
        );
        break;
      case 'webrtc.offer':
        // 主控端理论上不接收 offer，保留处理路径支持被控端重协商。
        final sdp = asString(event.data['sdp']);
        if (sdp.isNotEmpty && _peer != null) {
          final answer = await _peer!.handleOffer(sdp);
          _signaling.sendAnswer(answer);
        }
        break;
      case 'session.state':
        _handleSessionState(event.data);
        break;
      case 'privacy.sync':
        privacyBlackScreen = asBool(event.data['enabled']);
        notifyListeners();
        break;
      case 'session.closed':
        final reason = asString(event.data['reason'], fallback: 'peer_closed');
        _handleRemoteClosed(reason);
        break;
      case 'error':
        final code = event.code;
        if (code == 4040) {
          _fail('device_offline', event.displayMessage.isEmpty ? '设备已离线' : event.displayMessage);
        } else if (code == 4010) {
          _fail('auth_failed', event.displayMessage.isEmpty ? '验证码或密码错误' : event.displayMessage);
        } else {
          _fail('internal_error', event.displayMessage.isEmpty ? '信令错误' : event.displayMessage);
        }
        break;
      case 'socket.error':
      case 'socket.closed':
        _handleSignalingLost(event.message);
        break;
      default:
        break;
    }
  }

  Future<void> _handleConnectResult(SignalingMessage event) async {
    sessionId = event.sessionId.isNotEmpty ? event.sessionId : sessionId;
    final nextStage = RemoteStage.parse(asString(event.data['stage']));
    final accepted = asBool(event.data['accepted']);
    // 服务端在“等待对方确认”阶段会下发 accepted=false + stage=waiting_confirm，
    // 这表示尚未确认，不是拒绝，不能直接判定失败。
    if (!accepted && nextStage == RemoteStage.waitingConfirm) {
      stage = RemoteStage.waitingConfirm;
      connectionNotice = '等待对方确认';
      notifyListeners();
      return;
    }
    if (!accepted) {
      final reason = asString(event.data['reason'], fallback: 'rejected');
      _fail(reason, RemoteFailure.fromReason(reason).message);
      return;
    }
    if (nextStage != RemoteStage.idle && nextStage != RemoteStage.failed) {
      stage = nextStage;
      notifyListeners();
    }
    if (nextStage == RemoteStage.iceChecking ||
        nextStage == RemoteStage.p2pConnected ||
        nextStage == RemoteStage.relayConnected ||
        settings.autoReconnect) {
      await _ensurePeer();
    }
  }

  Future<void> _ensurePeer() async {
    if (_peer != null) return;
    final manager = PeerConnectionManager(
      iceServers: _iceServers.map((item) => item.toWebRtcJson()).toList(),
      onConnectionStateChanged: (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (!stage.isConnected) {
            stage = RemoteStage.p2pConnected;
          }
          _lastTrafficAt = DateTime.now();
          _markConnected();
          notifyListeners();
          requestDisplayList();
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _handlePeerFailed();
        }
      },
      onIceStateChanged: (state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          connectionNotice = '网络波动，正在尝试恢复';
          notifyListeners();
        }
      },
    );
    manager.onIceCandidate = (candidate) {
      _signaling.sendIce(
        candidate: candidate.candidate ?? '',
        // 保持字段非空，避免对端原生层把 null 当作对象处理导致崩溃。
        sdpMid: (candidate.sdpMid == null || candidate.sdpMid!.isEmpty)
            ? '0'
            : candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex ?? 0,
      );
    };
    _peer = manager;
    _subs.add(manager.controlMessages.listen(_onControlMessage));
    _subs.add(manager.chatMessages.listen(_onChatMessage));
    _subs.add(manager.clipboardMessages.listen(_onClipboardMessage));
    _subs.add(manager.statsStream.listen(_onStats));
    _subs.add(manager.metaMessages.listen(_onMeta));
    _subs.add(manager.connectionLog.listen((log) {
      if (kDebugMode) debugPrint('[remote] $log');
    }));
    try {
      await manager.initialize();
      renderer = manager.renderer;
      await manager.setSpeakerphoneOn(true);
      await manager.setRemoteAudioEnabled(audioEnabled);
    } catch (error) {
      await _disposePeer();
      _fail('internal_error', '建立媒体连接失败：$error');
      return;
    }
    notifyListeners();
    try {
      final offer = await manager.createOffer();
      _signaling.sendOffer(offer, sessionId: sessionId);
      connectionNotice = '已发送连接协商';
      notifyListeners();
    } catch (error) {
      _fail('internal_error', '建立媒体连接失败：$error');
    }
  }

  void _handleSessionState(Map<String, dynamic> data) {
    final nextStage = RemoteStage.parse(asString(data['stage']));
    if (nextStage != RemoteStage.idle) {
      stage = nextStage;
    }
    final transportName = asString(data['transport']);
    final candidateType = asString(data['candidateType']);
    transport = transport.copyWith(
      transport: transportName.isNotEmpty ? transportName : transport.transport,
      candidateType: candidateType.isNotEmpty ? candidateType : transport.candidateType,
      rttMs: asInt(data['rttMs'], fallback: transport.rttMs),
      lossRate: asDouble(data['lossRate'], fallback: transport.lossRate),
      bitrateKbps: asInt(data['bitrateKbps'], fallback: transport.bitrateKbps),
      fps: asInt(data['fps'], fallback: transport.fps),
      upBw: asInt(data['upBwKbps'], fallback: transport.upBw),
      downBw: asInt(data['downBwKbps'], fallback: transport.downBw),
      connectionState: asString(data['iceState'], fallback: transport.connectionState),
    );
    privacyBlackScreen = asBool(data['privacyBlackScreen'], fallback: privacyBlackScreen);
    final failureReason = asString(data['failureReason']);
    if (nextStage == RemoteStage.failed) {
      _fail(failureReason.isEmpty ? 'internal_error' : failureReason,
          RemoteFailure.fromReason(failureReason).message);
      return;
    }
    if (nextStage.isConnected) {
      _markConnected();
    }
    notifyListeners();
  }

  /// 连接成功后清零重连/重协商额度，避免额度跨会话累计。
  void _markConnected() {
    _reconnectAttempts = 0;
    _peerRetries = 0;
  }

  void _onControlMessage(Map<String, dynamic> message) {
    final type = asString(message['t']);
    if (type == 'privacy.sync') {
      privacyBlackScreen = asBool(message['enabled']);
      notifyListeners();
    } else if (type == 'camera.state') {
      cameraState = message;
      notifyListeners();
    }
  }

  void _onChatMessage(Map<String, dynamic> message) {
    chatMessages.add(message);
    notifyListeners();
  }

  void _onClipboardMessage(Map<String, dynamic> message) {
    final content = asString(message['content']);
    if (settings.clipboardSync && content.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: content));
    }
  }

  void _onStats(TransportInfo info) {
    final now = DateTime.now();
    final seconds = now.difference(_lastTrafficAt).inMilliseconds / 1000.0;
    _lastTrafficAt = now;
    final totalKbps = info.downBw + info.upBw;
    if (totalKbps > 0 && seconds > 0) {
      _trafficBytes += (totalKbps * 1000 / 8 * seconds).round();
    }
    transport = transport.copyWith(
      rttMs: info.rttMs > 0 ? info.rttMs : transport.rttMs,
      lossRate: info.lossRate > 0 ? info.lossRate : transport.lossRate,
      bitrateKbps: info.bitrateKbps > 0 ? info.bitrateKbps : transport.bitrateKbps,
      fps: info.fps > 0 ? info.fps : transport.fps,
      downBw: info.downBw,
      upBw: info.upBw,
      candidateType: info.candidateType.isNotEmpty ? info.candidateType : transport.candidateType,
      remoteAddress: info.remoteAddress.isNotEmpty ? info.remoteAddress : transport.remoteAddress,
      connectionState: info.connectionState.isNotEmpty ? info.connectionState : transport.connectionState,
      transport: _resolveTransport(info, transport.transport),
    );
    if (transport.isP2p && stage == RemoteStage.relayConnected) {
      stage = RemoteStage.p2pConnected;
    } else if (transport.isRelay && stage == RemoteStage.p2pConnected) {
      stage = RemoteStage.relayConnected;
    }
    _maybeAdaptQuality(info);
    notifyListeners();
  }

  /// 弱网自适应：按丢包/延迟动态下调码率，网络恢复后回升到不超过恢复阈值。
  void _maybeAdaptQuality(TransportInfo info) {
    if (!settings.lowBandwidthAdaptive || !connected) return;
    final now = DateTime.now();
    if (_lastQualityAdjustAt != null &&
        now.difference(_lastQualityAdjustAt!) < const Duration(seconds: 8)) {
      return;
    }
    final loss = info.lossRate > 0 ? info.lossRate : transport.lossRate;
    final rtt = info.rttMs > 0 ? info.rttMs : transport.rttMs;
    final limit = settings.bitrateLimit > 0 ? settings.bitrateLimit : 4000;
    final current = transport.bitrateKbps > 0 ? transport.bitrateKbps : limit;
    if (loss >= 0.05 || rtt >= 350) {
      final target = math.max(settings.minBitrate, (current * 0.8).round());
      if (target < current) {
        updateQuality(preset: settings.qualityPreset, bitrateKbps: target);
        _lastQualityAdjustAt = now;
      }
    } else if (loss <= 0.01 && rtt < 150 && current < settings.restoreThreshold) {
      final target = math.min(limit, (current * 1.1).round());
      if (target > current) {
        updateQuality(preset: settings.qualityPreset, bitrateKbps: target);
        _lastQualityAdjustAt = now;
      }
    }
  }

  String _resolveTransport(TransportInfo info, String current) {
    if (info.transport.isNotEmpty) return info.transport;
    if (info.candidateType == 'relay') return 'relay';
    if (info.candidateType == 'host' || info.candidateType == 'srflx') return 'p2p';
    return current;
  }

  void _onMeta(Map<String, dynamic> message) {
    final type = asString(message['t']);
    if (type == 'displays' || type == 'displays.update') {
      final list = asList(message['items'] ?? message['displays'])
          .map((item) => DisplayInfo.fromJson(asMap(item)))
          .toList();
      if (list.isNotEmpty) {
        displays = list;
        if (activeDisplayId.isEmpty) {
          activeDisplayId = displays
              .firstWhere((item) => item.primary, orElse: () => displays.first)
              .id;
        }
      }
    } else if (type == 'camera.state') {
      cameraState = message;
    }
    notifyListeners();
  }

  void _handlePeerFailed() {
    if (_closedByUser || stage == RemoteStage.failed) return;
    // 网络切换/NAT 映射变化时先重新协商一次，避免直接判死。
    if (_peerRetries < 2) {
      _peerRetries++;
      connectionNotice = '连接不稳定，正在重新协商（$_peerRetries/2）';
      notifyListeners();
      unawaited(_restartPeer());
      return;
    }
    final relay = settings.allowRelay ? '中继' : '中继（已关闭）';
    _fail('network_unreachable', '媒体连接失败，已尝试 P2P 与$relay，请检查网络后重试');
  }

  Future<void> _restartPeer() async {
    await _disposePeer();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (_closedByUser || stage == RemoteStage.failed) return;
    try {
      await _ensurePeer();
    } catch (_) {
      // 服务端不支持重复 offer 时，回退为完整重连。
      await _reconnect();
    }
  }

  void _handleRemoteClosed(String reason) {
    if (_closedByUser) return;
    // 已经进入失败态时保留更具体的失败原因，避免被“会话已结束”覆盖。
    if (stage == RemoteStage.failed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    releaseAllKeys();
    unawaited(_disposePeer());
    final normalized = reason.trim();
    final ended = normalized.isEmpty ||
        normalized == 'peer_closed' ||
        normalized == 'closed';
    failure = RemoteFailure(
      normalized.isEmpty ? 'peer_closed' : normalized,
      ended ? '对方已结束远程会话' : RemoteFailure.fromReason(normalized).message,
    );
    stage = RemoteStage.failed;
    _stopTicking();
    notifyListeners();
  }

  void _handleSignalingLost(String message) {
    if (_closedByUser) return;
    if (stage == RemoteStage.failed) return;
    if (settings.autoReconnect && _reconnectAttempts < 3) {
      _reconnectAttempts++;
      connectionNotice = '信令断开，${
        settings.reconnectInterval
      } 秒后自动重连（$_reconnectAttempts/3）';
      notifyListeners();
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(
        Duration(seconds: math.max(1, settings.reconnectInterval)),
        _reconnect,
      );
      return;
    }
    _fail('network_unreachable', message.isEmpty ? '网络连接中断' : message);
  }

  Future<void> _reconnect() async {
    await _disposePeer();
    _subs.removeWhere((sub) {
      sub.cancel();
      return true;
    });
    sessionId = '';
    stage = RemoteStage.matching;
    failure = null;
    // 重连属于新会话，必须清掉上一轮的画面状态，否则会残留隐私遮罩、旧显示器列表与传输指标。
    privacyBlackScreen = false;
    displays = const [];
    activeDisplayId = '';
    transport = const TransportInfo();
    cameraState = const {};
    notifyListeners();
    await start();
  }

  Future<void> manualReconnect() async {
    _reconnectAttempts = 0;
    _closedByUser = false;
    _reconnectTimer?.cancel();
    await _reconnect();
  }

  void _fail(String reason, String message) {
    if (stage == RemoteStage.failed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    releaseAllKeys();
    failure = RemoteFailure(reason, message);
    stage = RemoteStage.failed;
    _stopTicking();
    notifyListeners();
  }

  void _stopTicking() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _uiTicker?.cancel();
    _uiTicker = null;
    WakelockPlus.disable();
  }

  void setViewOnly(bool value) {
    viewOnly = value;
    _signaling.sendControlRequest(
      action: 'mode.update',
      payload: {'mode': value ? 'view' : 'control'},
    );
    notifyListeners();
  }

  void toggleAntiTouch() {
    antiTouch = !antiTouch;
    notifyListeners();
  }

  void unlockAntiTouch() {
    antiTouch = false;
    notifyListeners();
  }

  void setTrackballMode(bool value) {
    trackballMode = value;
    notifyListeners();
  }

  void toggleCursor() {
    cursorHidden = !cursorHidden;
    _signaling.sendControlRequest(action: 'cursor.toggle', payload: {'hidden': cursorHidden});
    notifyListeners();
  }

  void mouseMove(double x, double y) {
    if (!canForwardInput) return;
    _peer?.moveMouse(x, y);
  }

  void mouseDown(double x, double y, {String button = 'left'}) {
    if (!canForwardInput) return;
    if (settings.hapticsEnabled) HapticFeedback.lightImpact();
    _peer?.mouseButton(button, true, x, y);
  }

  void mouseUp(double x, double y, {String button = 'left'}) {
    if (!canForwardInput) return;
    _peer?.mouseButton(button, false, x, y);
  }

  void leftClick(double x, double y) {
    if (!canForwardInput) return;
    if (settings.hapticsEnabled) HapticFeedback.selectionClick();
    _peer?.mouseButton('left', true, x, y);
    _peer?.mouseButton('left', false, x, y);
  }

  void rightClick(double x, double y) {
    if (!canForwardInput) return;
    if (settings.hapticsEnabled) HapticFeedback.mediumImpact();
    _peer?.mouseButton('right', true, x, y);
    _peer?.mouseButton('right', false, x, y);
  }

  void wheel(int delta) {
    if (!canForwardInput) return;
    _peer?.wheel((delta * settings.scrollSensitivity).round());
  }

  void key(String code, bool down, {List<String> modifiers = const []}) {
    if (!canForwardInput) return;
    if (down) {
      _heldKeys.add(code);
    } else {
      _heldKeys.remove(code);
    }
    _peer?.key(code, down, modifiers: modifiers);
  }

  /// 退出会话、切后台、关闭键盘时统一抬起，避免被控端按键卡住。
  void releaseAllKeys() {
    final held = _heldKeys.toList();
    _heldKeys.clear();
    for (final code in held) {
      _peer?.key(code, false);
    }
  }

  void keyCombo(List<String> keys) {
    if (!canForwardInput) return;
    _peer?.keyCombo(keys);
  }

  void sendText(String value) {
    if (!canForwardInput || value.isEmpty) return;
    _peer?.text(value);
  }

  void sendClipboard(String text) {
    if (!settings.clipboardSync || text.isEmpty) return;
    _peer?.clipboard('text', text);
  }

  Future<void> pasteFromPhone() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      sendClipboard(text);
      _peer?.text(text);
    }
  }

  void toggleAudio() {
    audioEnabled = !audioEnabled;
    _peer?.setRemoteAudioEnabled(audioEnabled);
    notifyListeners();
  }

  void setAudioEnabled(bool value) {
    audioEnabled = value;
    _peer?.setRemoteAudioEnabled(value);
    notifyListeners();
  }

  void toggleMicrophone() {
    microphoneEnabled = !microphoneEnabled;
    _signaling.sendControlRequest(
      action: 'audio.mic',
      payload: {'enabled': microphoneEnabled},
    );
    notifyListeners();
  }

  Future<bool> togglePrivacy(bool value) async {
    // 隐私黑屏由被控端权威执行，主控仅发送同步消息，最终状态以 privacy.sync 回传为准。
    _signaling.sendPrivacy(value);
    _signaling.sendControlRequest(action: 'privacy.set', payload: {'enabled': value});
    // 信令可能正在重连，同时走已建立的 control 数据通道，避免指令丢失。
    _peer?.sendControl({'t': 'privacy.sync', 'enabled': value});
    privacyBlackScreen = value;
    notifyListeners();
    return true;
  }

  void setPrivacyMirror(bool value) {
    privacyBlackScreen = value;
    notifyListeners();
  }

  void requestSystemAction(String action) {
    _peer?.systemAction(action);
  }

  void requestDisplayList() {
    _signaling.sendControlRequest(action: 'display.list');
  }

  void switchDisplay(DisplayInfo display) {
    activeDisplayId = display.id;
    _signaling.sendControlRequest(
      action: 'display.select',
      payload: {
        'displayId': display.id,
        'index': asInt(display.id),
      },
    );
    notifyListeners();
  }

  void updateQuality({
    required String preset,
    int? fps,
    int? bitrateKbps,
    double? resolutionScale,
    String? encoder,
  }) {
    _signaling.sendControlRequest(
      action: 'quality.update',
      payload: {
        'preset': preset,
        'fps': fps ?? settings.fpsLimit,
        'bitrateKbps': bitrateKbps ?? settings.bitrateLimit,
        'resolutionScale': resolutionScale ?? settings.resolutionScale,
        'encoder': encoder ?? settings.encoder,
        'adaptive': settings.adaptiveQuality,
      },
    );
  }

  void toggleCameraPreview() {
    final enabled = !asBool(cameraState['enabled']);
    _signaling.sendControlRequest(
      action: 'camera.preview',
      payload: {'enabled': enabled},
    );
    cameraState = {...cameraState, 'enabled': enabled};
    notifyListeners();
  }

  Future<bool> enterPip() async {
    final ok = await services.native.enterPictureInPicture();
    if (ok) {
      pipActive = true;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> startCasting() async {
    final ok = await services.native.startCast(
      fps: settings.fpsLimit,
      bitrateKbps: settings.bitrateLimit > 0 ? settings.bitrateLimit : 2000,
    );
    castingActive = ok;
    castMode = ok;
    notifyListeners();
    return ok;
  }

  Future<void> stopCasting() async {
    await services.native.stopCast();
    castingActive = false;
    notifyListeners();
  }

  Future<bool> startRecording() async {
    final ok = await services.native.startScreenRecording();
    if (ok) {
      recording = true;
      notifyListeners();
    }
    return ok;
  }

  Future<String?> stopRecording() async {
    final path = await services.native.stopScreenRecording();
    recording = false;
    notifyListeners();
    return path;
  }

  void setCameraState(Map<String, dynamic> state) {
    cameraState = state;
    notifyListeners();
  }

  void onLocalClipboardChanged(String? text) {
    if (text != null && text.isNotEmpty && settings.clipboardSync) {
      sendClipboard(text);
    }
  }

  Future<void> endSession({bool notifyPeer = true}) async {
    _closedByUser = true;
    releaseAllKeys();
    if (notifyPeer) {
      try {
        _signaling.closeSession();
      } catch (_) {}
    }
    _stopTicking();
    _reconnectTimer?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _signaling.dispose();
    await _disposePeer();
    if (castingActive) {
      await services.native.stopCast();
    }
    if (Platform.isAndroid) {
      await services.native.stopRemoteForegroundService();
    }
    notifyListeners();
  }

  Future<void> _disposePeer() async {
    final peer = _peer;
    _peer = null;
    renderer = null;
    await peer?.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _closedByUser = true;
    releaseAllKeys();
    _durationTimer?.cancel();
    _uiTicker?.cancel();
    _reconnectTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _signaling.dispose();
    _peer?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}

/// 远程文件页需要复用当前会话的 DataChannel。
class RemoteSessionRegistry {
  RemoteSessionRegistry._();

  static final RemoteSessionRegistry instance = RemoteSessionRegistry._();

  RemoteSessionProvider? current;
}
