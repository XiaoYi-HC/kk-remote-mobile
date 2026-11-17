import '../../core/utils/json_utils.dart';

enum RemoteStage {
  idle,
  matching,
  waitingConfirm,
  iceChecking,
  p2pConnected,
  relayConnected,
  failed;

  static RemoteStage parse(String? value) {
    switch (value) {
      case 'matching':
        return RemoteStage.matching;
      case 'waiting_confirm':
        return RemoteStage.waitingConfirm;
      case 'ice_checking':
        return RemoteStage.iceChecking;
      case 'p2p_connected':
        return RemoteStage.p2pConnected;
      case 'relay_connected':
        return RemoteStage.relayConnected;
      case 'failed':
        return RemoteStage.failed;
      default:
        return RemoteStage.idle;
    }
  }

  bool get isConnected =>
      this == RemoteStage.p2pConnected || this == RemoteStage.relayConnected;

  bool get isTerminal => this == RemoteStage.failed;
}

class TransportInfo {
  const TransportInfo({
    this.transport = '',
    this.candidateType = '',
    this.rttMs = 0,
    this.lossRate = 0,
    this.bitrateKbps = 0,
    this.fps = 0,
    this.upBw = 0,
    this.downBw = 0,
    this.remoteAddress = '',
    this.connectionState = '',
    this.turnUrl = '',
  });

  final String transport;
  final String candidateType;
  final int rttMs;
  final double lossRate;
  final int bitrateKbps;
  final int fps;
  final int upBw;
  final int downBw;
  final String remoteAddress;
  final String connectionState;
  final String turnUrl;

  bool get isP2p => transport == 'p2p';
  bool get isRelay => transport == 'relay';

  String get label {
    if (transport == 'p2p') return 'P2P';
    if (transport == 'relay') return '中继';
    return '连接中';
  }

  factory TransportInfo.fromJson(Map<String, dynamic> json) {
    return TransportInfo(
      transport: asString(json['transport']),
      candidateType: asString(json['candidateType']),
      rttMs: asInt(json['rttMs']),
      lossRate: asDouble(json['lossRate']),
      bitrateKbps: asInt(json['bitrateKbps']),
      fps: asInt(json['fps']),
      upBw: asInt(json['upBw']),
      downBw: asInt(json['downBw']),
      remoteAddress: asString(json['remoteAddress']),
      connectionState: asString(json['connectionState']),
      turnUrl: asString(json['turnUrl']),
    );
  }

  TransportInfo copyWith({
    String? transport,
    String? candidateType,
    int? rttMs,
    double? lossRate,
    int? bitrateKbps,
    int? fps,
    int? upBw,
    int? downBw,
    String? remoteAddress,
    String? connectionState,
    String? turnUrl,
  }) {
    return TransportInfo(
      transport: transport ?? this.transport,
      candidateType: candidateType ?? this.candidateType,
      rttMs: rttMs ?? this.rttMs,
      lossRate: lossRate ?? this.lossRate,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      fps: fps ?? this.fps,
      upBw: upBw ?? this.upBw,
      downBw: downBw ?? this.downBw,
      remoteAddress: remoteAddress ?? this.remoteAddress,
      connectionState: connectionState ?? this.connectionState,
      turnUrl: turnUrl ?? this.turnUrl,
    );
  }
}

class DisplayInfo {
  const DisplayInfo({
    required this.id,
    this.name = '',
    this.width = 0,
    this.height = 0,
    this.primary = false,
    this.thumbnail = '',
  });

  final String id;
  final String name;
  final int width;
  final int height;
  final bool primary;
  final String thumbnail;

  String get resolutionLabel => width <= 0 || height <= 0 ? '--' : '$width×$height';
  String get label => name.isNotEmpty ? name : '显示器 $id';

  factory DisplayInfo.fromJson(Map<String, dynamic> json) {
    return DisplayInfo(
      id: asString(json['id'], fallback: '0'),
      name: asString(json['name']),
      width: asInt(json['width']),
      height: asInt(json['height']),
      primary: asBool(json['primary']),
      thumbnail: asString(json['thumbnail']),
    );
  }
}

class RemoteFailure {
  const RemoteFailure(this.reason, this.message);

  final String reason;
  final String message;

  static RemoteFailure fromReason(String? reason) {
    switch (reason) {
      case 'timeout':
        return const RemoteFailure('timeout', '等待对方确认超时，请确认被控电脑已开启');
      case 'rejected':
        return const RemoteFailure('rejected', '对方拒绝了本次连接请求');
      case 'network_unreachable':
        return const RemoteFailure('network_unreachable', '网络不可达，请切换网络后重试');
      case 'device_offline':
        return const RemoteFailure('device_offline', '设备已离线，请确认被控端在线');
      case 'auth_failed':
        return const RemoteFailure('auth_failed', '验证码或无人值守密码错误');
      case 'version_incompatible':
        return const RemoteFailure('version_incompatible', '双方版本不兼容，请升级后重试');
      default:
        return const RemoteFailure('internal_error', '连接失败，请稍后重试');
    }
  }
}
