import '../../../data/models/device.dart';

class RemoteArgs {
  const RemoteArgs({
    required this.deviceCode,
    this.deviceName = '',
    this.deviceId = 0,
    this.verifyCode = '',
    this.password = '',
    this.mode = 'control',
    this.isLan = false,
    this.lanIp = '',
    this.castMode = false,
    this.guest = false,
  });

  final String deviceCode;
  final String deviceName;
  final int deviceId;
  final String verifyCode;
  final String password;
  final String mode;
  final bool isLan;
  final String lanIp;
  final bool castMode;
  final bool guest;

  String get displayName => deviceName.isEmpty ? deviceCode : deviceName;

  factory RemoteArgs.fromDevice(
    Device device, {
    String verifyCode = '',
    String password = '',
    bool castMode = false,
  }) {
    return RemoteArgs(
      deviceCode: device.deviceCode,
      deviceName: device.displayName,
      deviceId: device.id,
      verifyCode: verifyCode,
      password: password,
      isLan: device.lan,
      castMode: castMode,
    );
  }
}
