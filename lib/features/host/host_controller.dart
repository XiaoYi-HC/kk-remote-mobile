import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/json_utils.dart';
import '../../data/models/common.dart';
import '../../data/ws/signaling_client.dart';
import '../../state/app_services.dart';
import 'host_api.dart';
import 'host_models.dart';

enum HostShareStatus { registering, ready, incoming, connecting, sharing, error }

/// 移动端被控（屏幕共享 + 双向语音）控制器。
///
/// 只发布屏幕视频与麦克风音频，不接收键鼠控制，也不启用摄像头。
class HostShareController extends ChangeNotifier {
  HostShareController(this._services);

  final AppServices _services;

  static const _deviceUuidKey = 'host_device_uuid';
  static const _deviceSecretKey = 'host_device_secret';
  static const _deviceTokenKey = 'host_device_token';

  late final HostApi _api = HostApi(baseUrl: _services.settings.resolvedApiBaseUrl);
  final SignalingClient _signaling = SignalingClient();
  StreamSubscription<SignalingMessage>? _eventSub;

  HostRegistration? registration;
  HostShareStatus status = HostShareStatus.registering;
  String? error;
  HostIncomingCall? incoming;
  bool micEnabled = true;

  bool _sharing = false;
  bool _disposed = false;
  String _sessionId = '';

  RTCPeerConnection? _pc;
  MediaStream? _screenStream;
  MediaStream? _micStream;
  RTCRtpSender? _micSender;
  List<IceServerConfig> _iceServers = const [];

  final List<RTCIceCandidate> _pendingCandidates = [];
  String? _pendingOffer;
  bool _remoteDescriptionSet = false;
  Timer? _codeTimer;

  bool get sharing => _sharing;
  bool get online => _signaling.isConnected;
  bool get supported => Platform.isAndroid || Platform.isIOS;

  String get platformLabel => Platform.isIOS ? 'iOS' : 'Android';

  Future<void> init() async {
    if (_disposed) return;
    _setStatus(HostShareStatus.registering);
    try {
      final store = _services.store;
      var uuid = store.getString(_deviceUuidKey) ?? '';
      if (uuid.isEmpty) {
        uuid = const Uuid().v4();
        await store.setString(_deviceUuidKey, uuid);
      }
      final secret = store.getString(_deviceSecretKey) ?? '';
      // 注册时携带当前用户 token，便于后端把设备归属到账号（后端未启用时会被忽略）。
      _api.setToken(_services.api.token);
      final reg = await _api.register(
        deviceUuid: uuid,
        name: Platform.isIOS ? 'KK远程 iPhone' : 'KK远程 Android 手机',
        osVersion: Platform.operatingSystemVersion,
        deviceSecret: secret,
      );
      if (reg.deviceSecret.isNotEmpty) {
        await store.setString(_deviceSecretKey, reg.deviceSecret);
      }
      if (reg.deviceToken.isNotEmpty) {
        await store.setString(_deviceTokenKey, reg.deviceToken);
      }
      registration = reg;
      _api.setDeviceToken(reg.deviceToken);
      _iceServers = await _loadIceServers();
      await _connectSignaling(reg);
      _setStatus(HostShareStatus.ready);
      _scheduleCodeRefresh();
    } catch (err) {
      _fail('注册设备失败：$err');
    }
  }

  Future<List<IceServerConfig>> _loadIceServers() async {
    try {
      final data = await _services.api.get('/client/config/bootstrap', query: {
        'platform': HostApi.platform,
        'version': AppConstants.appVersion,
      });
      final map = asMap(data);
      final list = asList(map['iceServers'])
          .map((item) => IceServerConfig.fromJson(asMap(item)))
          .where((item) => item.urls.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {
      // ignore and fall back below
    }
    return const [IceServerConfig(urls: ['stun:stun.l.google.com:19302'])];
  }

  Future<void> _connectSignaling(HostRegistration reg) async {
    await _eventSub?.cancel();
    _eventSub = _signaling.events.listen(_onSignal);
    final url = reg.signalingUrl.isNotEmpty ? reg.signalingUrl : _services.signalingUrl;
    await _signaling.connect(
      signalingUrl: url,
      token: reg.deviceToken,
      role: 'host',
      platform: HostApi.platform,
      version: AppConstants.appVersion,
    );
  }

  void _onSignal(SignalingMessage msg) {
    if (_disposed) return;
    switch (msg.type) {
      case 'connect.incoming':
        final data = Map<String, dynamic>.from(msg.data);
        if (asString(data['sessionId']).isEmpty && msg.sessionId.isNotEmpty) {
          data['sessionId'] = msg.sessionId;
        }
        final call = HostIncomingCall.fromJson(data);
        if (call.sessionId.isEmpty) return;
        incoming = call;
        _setStatus(HostShareStatus.incoming);
        if (call.autoAccept) {
          unawaited(accept());
        }
        break;
      case 'connect.result':
        if (msg.data['accepted'] == false) {
          _fail('对方已取消连接');
          return;
        }
        if (asString(msg.data['stage']) == 'ice_checking') {
          _setStatus(HostShareStatus.connecting);
        }
        break;
      case 'webrtc.offer':
        unawaited(_handleOffer(asString(msg.data['sdp']), msg.sessionId));
        break;
      case 'webrtc.ice':
        unawaited(_addRemoteCandidate(msg.data));
        break;
      case 'session.closed':
        unawaited(_endSession(asString(msg.data['reason'])));
        break;
      case 'socket.closed':
      case 'socket.error':
        if (!_disposed) _fail(msg.displayMessage.isEmpty ? '信令连接已断开' : msg.displayMessage);
        break;
      case 'error':
        if (!_disposed && msg.displayMessage.isNotEmpty) {
          error = msg.displayMessage;
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  Future<void> accept() async {
    final call = incoming;
    if (call == null) return;
    incoming = null;
    if (!_sharing) {
      await startShare();
    }
    if (!_sharing) {
      reject(reason: '对方未开始屏幕共享');
      return;
    }
    _sessionId = call.sessionId;
    _signaling.send('connect.accept', sessionId: call.sessionId);
    _setStatus(HostShareStatus.connecting);
    final offer = _pendingOffer;
    if (offer != null && offer.isNotEmpty) {
      _pendingOffer = null;
      unawaited(_handleOffer(offer, call.sessionId));
    }
  }

  void reject({String reason = '对方已拒绝'}) {
    final call = incoming;
    incoming = null;
    if (call != null) {
      _signaling.send('connect.reject', data: {'reason': reason}, sessionId: call.sessionId);
    }
    if (_sharing) {
      _setStatus(HostShareStatus.ready);
    } else {
      _setStatus(HostShareStatus.ready);
    }
  }

  Future<void> startShare() async {
    if (_sharing || _disposed) return;
    error = null;
    try {
      // 先申请麦克风权限，再启动前台服务，避免 Android 14 因缺少录音权限拒绝 microphone 类型。
      if (micEnabled) {
        await _ensureMic();
      }
      if (Platform.isAndroid) {
        await _services.native.startScreenShareService();
      }
      final constraints = <String, dynamic>{
        'video': Platform.isIOS ? {'deviceId': 'broadcast'} : {'frameRate': 24},
        'audio': false,
      };
      _screenStream = await navigator.mediaDevices.getDisplayMedia(constraints);
      _sharing = true;
      notifyListeners();
      if (status != HostShareStatus.connecting && status != HostShareStatus.incoming) {
        _setStatus(HostShareStatus.ready);
      }
      final offer = _pendingOffer;
      if (offer != null && offer.isNotEmpty) {
        _pendingOffer = null;
        unawaited(_handleOffer(offer, _sessionId));
      }
    } catch (err) {
      await stopShare();
      _fail('无法开始屏幕共享：$err');
    }
  }

  Future<void> stopShare() async {
    _sharing = false;
    _pendingOffer = null;
    _sessionId = '';
    incoming = null;
    await _closePeer();
    for (final track in _screenStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _screenStream?.dispose();
    _screenStream = null;
    for (final track in _micStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _micStream?.dispose();
    _micStream = null;
    _micSender = null;
    if (Platform.isAndroid) {
      await _services.native.stopScreenShareService();
    }
    if (!_disposed && status != HostShareStatus.error) {
      _setStatus(HostShareStatus.ready);
    } else {
      notifyListeners();
    }
  }

  Future<void> setMicEnabled(bool value) async {
    micEnabled = value;
    if (value && _sharing && _micStream == null) {
      try {
        await _ensureMic();
      } catch (err) {
        error = '无法打开麦克风：$err';
      }
    }
    final track =
        _micStream?.getAudioTracks().isNotEmpty == true ? _micStream!.getAudioTracks().first : null;
    if (track != null) track.enabled = value;
    notifyListeners();
  }

  Future<void> _ensureMic() async {
    if (_micStream != null) return;
    _micStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    final track =
        _micStream!.getAudioTracks().isNotEmpty ? _micStream!.getAudioTracks().first : null;
    if (track != null) {
      track.enabled = micEnabled;
      await _micSender?.replaceTrack(track);
    }
  }

  Future<RTCPeerConnection?> _ensurePeer() async {
    if (_pc != null) return _pc;
    if (_screenStream == null) return null;
    final config = <String, dynamic>{
      'iceServers': _iceServers.map((item) => item.toWebRtcJson()).toList(),
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
    final videoTracks = _screenStream!.getVideoTracks();
    final videoTx = await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendOnly),
    );
    if (videoTracks.isNotEmpty) {
      await videoTx.sender.replaceTrack(videoTracks.first);
    }
    final audioTx = await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
    );
    _micSender = audioTx.sender;
    final micTracks = _micStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (micTracks.isNotEmpty) {
      await _micSender!.replaceTrack(micTracks.first);
    }
    pc.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) return;
      _signaling.sendIce(
        candidate: value,
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
        sessionId: _sessionId.isEmpty ? null : _sessionId,
      );
    };
    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _setStatus(HostShareStatus.sharing);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _fail('网络连接失败，请让桌面端重新连接');
      }
    };
    return pc;
  }

  Future<void> _handleOffer(String sdp, String sessionId) async {
    if (sdp.isEmpty) return;
    if (sessionId.isNotEmpty) _sessionId = sessionId;
    if (!_sharing) {
      _pendingOffer = sdp;
      return;
    }
    final pc = await _ensurePeer();
    if (pc == null) {
      _pendingOffer = sdp;
      return;
    }
    try {
      await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      _remoteDescriptionSet = true;
      for (final candidate in _pendingCandidates) {
        try {
          await pc.addCandidate(candidate);
        } catch (_) {}
      }
      _pendingCandidates.clear();
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _signaling.sendAnswer(answer.sdp ?? '', sessionId: _sessionId);
      _setStatus(HostShareStatus.connecting);
    } catch (err) {
      _fail('画面协商失败：$err');
    }
  }

  Future<void> _addRemoteCandidate(Map<String, dynamic> data) async {
    final value = asString(data['candidate']);
    if (value.isEmpty) return;
    final candidate = RTCIceCandidate(
      value,
      asString(data['sdpMid']),
      asInt(data['sdpMLineIndex']),
    );
    final pc = _pc;
    if (pc == null || !_remoteDescriptionSet) {
      _pendingCandidates.add(candidate);
      return;
    }
    try {
      await pc.addCandidate(candidate);
    } catch (_) {}
  }

  Future<void> _endSession(String reason) async {
    await _closePeer();
    _sessionId = '';
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();
    incoming = null;
    if (_sharing) {
      await stopShare();
    } else {
      _setStatus(HostShareStatus.ready);
    }
  }

  Future<void> _closePeer() async {
    final pc = _pc;
    _pc = null;
    _remoteDescriptionSet = false;
    if (pc != null) {
      pc.onIceCandidate = null;
      pc.onConnectionState = null;
      try {
        await pc.close();
      } catch (_) {}
      try {
        await pc.dispose();
      } catch (_) {}
    }
  }

  void _scheduleCodeRefresh() {
    _codeTimer?.cancel();
    _codeTimer = Timer.periodic(const Duration(minutes: 20), (_) async {
      final reg = registration;
      if (reg == null || _disposed) return;
      try {
        final (code, expires) = await _api.refreshVerificationCode();
        if (code.isEmpty || _disposed) return;
        registration = reg.copyWith(
          verificationCode: code,
          verificationExpiresAt: expires,
        );
        notifyListeners();
      } catch (_) {}
    });
  }

  Future<void> retry() async {
    _codeTimer?.cancel();
    await _eventSub?.cancel();
    await _signaling.close();
    await _closePeer();
    registration = null;
    await init();
  }

  void _setStatus(HostShareStatus value) {
    status = value;
    if (value != HostShareStatus.error) error = null;
    notifyListeners();
  }

  void _fail(String message) {
    status = HostShareStatus.error;
    error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _codeTimer?.cancel();
    _eventSub?.cancel();
    _signaling.close();
    unawaited(_closePeer());
    unawaited(_screenStream?.dispose() ?? Future<void>.value());
    unawaited(_micStream?.dispose() ?? Future<void>.value());
    super.dispose();
  }
}
