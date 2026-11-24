import '../../core/utils/json_utils.dart';

/// 移动端被控（屏幕共享）注册结果。
class HostRegistration {
  const HostRegistration({
    required this.deviceId,
    required this.deviceCode,
    required this.deviceToken,
    required this.deviceSecret,
    required this.verificationCode,
    required this.verificationExpiresAt,
    required this.signalingUrl,
    required this.apiBaseUrl,
  });

  final int deviceId;
  final String deviceCode;
  final String deviceToken;
  final String deviceSecret;
  final String verificationCode;
  final int verificationExpiresAt;
  final String signalingUrl;
  final String apiBaseUrl;

  factory HostRegistration.fromJson(Map<String, dynamic> json) {
    return HostRegistration(
      deviceId: asInt(json['deviceId']),
      deviceCode: asString(json['deviceCode']),
      deviceToken: asString(json['deviceToken']),
      deviceSecret: asString(json['deviceSecret']),
      verificationCode: asString(json['verificationCode']),
      verificationExpiresAt: asInt(json['verificationExpiresAt']),
      signalingUrl: asString(json['signalingUrl']),
      apiBaseUrl: asString(json['apiBaseUrl']),
    );
  }

  HostRegistration copyWith({
    String? deviceCode,
    String? deviceToken,
    String? deviceSecret,
    String? verificationCode,
    int? verificationExpiresAt,
  }) {
    return HostRegistration(
      deviceId: deviceId,
      deviceCode: deviceCode ?? this.deviceCode,
      deviceToken: deviceToken ?? this.deviceToken,
      deviceSecret: deviceSecret ?? this.deviceSecret,
      verificationCode: verificationCode ?? this.verificationCode,
      verificationExpiresAt: verificationExpiresAt ?? this.verificationExpiresAt,
      signalingUrl: signalingUrl,
      apiBaseUrl: apiBaseUrl,
    );
  }
}

/// 桌面端发起的连接请求（被控端视角）。
class HostIncomingCall {
  const HostIncomingCall({
    required this.sessionId,
    this.controllerAccount = '',
    this.controllerDeviceName = '',
    this.controllerPlatform = '',
    this.controllerIp = '',
    this.mode = 'view',
    this.autoAccept = false,
    this.expiresInSec = 30,
  });

  final String sessionId;
  final String controllerAccount;
  final String controllerDeviceName;
  final String controllerPlatform;
  final String controllerIp;
  final String mode;
  final bool autoAccept;
  final int expiresInSec;

  String get displayName => controllerDeviceName.isNotEmpty
      ? controllerDeviceName
      : (controllerAccount.isNotEmpty ? controllerAccount : '桌面端');

  String get platformLabel {
    switch (controllerPlatform.toLowerCase()) {
      case 'windows':
        return 'Windows';
      case 'macos':
      case 'mac':
        return 'macOS';
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      default:
        return controllerPlatform.isEmpty ? '桌面端' : controllerPlatform;
    }
  }

  factory HostIncomingCall.fromJson(Map<String, dynamic> json) {
    return HostIncomingCall(
      sessionId: asString(json['sessionId']),
      controllerAccount: asString(json['controllerAccount']),
      controllerDeviceName: asString(json['controllerDeviceName']),
      controllerPlatform: asString(json['controllerPlatform']),
      controllerIp: asString(json['controllerIp']),
      mode: asString(json['mode'], fallback: 'view'),
      autoAccept: asBool(json['autoAccept']),
      expiresInSec: asInt(json['expiresInSec'], fallback: 30),
    );
  }
}
