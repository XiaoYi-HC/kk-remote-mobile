class ConnectArgs {
  const ConnectArgs({
    this.deviceCode = '',
    this.deviceName = '',
    this.deviceId = 0,
    this.isLan = false,
    this.lanIp = '',
    this.castMode = false,
    this.showBindOption = true,
  });

  final String deviceCode;
  final String deviceName;
  final int deviceId;
  final bool isLan;
  final String lanIp;
  final bool castMode;
  final bool showBindOption;
}
