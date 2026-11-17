import '../../core/utils/json_utils.dart';

class SessionRecord {
  const SessionRecord({
    this.id = 0,
    this.sessionNo = '',
    this.controllerAccount = '',
    this.hostDeviceId = 0,
    this.hostDeviceCode = '',
    this.hostDeviceName = '',
    this.stage = '',
    this.transport = '',
    this.candidateType = '',
    this.startedAt,
    this.acceptedAt,
    this.endedAt,
    this.durationSec = 0,
    this.avgRttMs = 0,
    this.avgLossRate = 0,
    this.avgBitrateKbps = 0,
    this.avgFps = 0,
    this.privacyBlackScreen = false,
    this.fileTransferred = false,
    this.relayBytesUp = 0,
    this.relayBytesDown = 0,
    this.endReason = '',
    this.qualityPreset = '',
  });

  final int id;
  final String sessionNo;
  final String controllerAccount;
  final int hostDeviceId;
  final String hostDeviceCode;
  final String hostDeviceName;
  final String stage;
  final String transport;
  final String candidateType;
  final DateTime? startedAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final int durationSec;
  final int avgRttMs;
  final double avgLossRate;
  final int avgBitrateKbps;
  final int avgFps;
  final bool privacyBlackScreen;
  final bool fileTransferred;
  final int relayBytesUp;
  final int relayBytesDown;
  final String endReason;
  final String qualityPreset;

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      id: asInt(json['id']),
      sessionNo: asString(json['sessionNo']),
      controllerAccount: asString(json['controllerAccount']),
      hostDeviceId: asInt(json['hostDeviceId']),
      hostDeviceCode: asString(json['hostDeviceCode']),
      hostDeviceName: asString(json['hostDeviceName']),
      stage: asString(json['stage']),
      transport: asString(json['transport']),
      candidateType: asString(json['candidateType']),
      startedAt: asDate(json['startedAt']),
      acceptedAt: asDate(json['acceptedAt']),
      endedAt: asDate(json['endedAt']),
      durationSec: asInt(json['durationSec']),
      avgRttMs: asInt(json['avgRttMs']),
      avgLossRate: asDouble(json['avgLossRate']),
      avgBitrateKbps: asInt(json['avgBitrateKbps']),
      avgFps: asInt(json['avgFps']),
      privacyBlackScreen: asBool(json['privacyBlackScreen']),
      fileTransferred: asBool(json['fileTransferred']),
      relayBytesUp: asInt(json['relayBytesUp']),
      relayBytesDown: asInt(json['relayBytesDown']),
      endReason: asString(json['endReason']),
      qualityPreset: asString(json['qualityPreset']),
    );
  }
}

class TransferRecord {
  const TransferRecord({
    this.id = 0,
    this.sessionId = 0,
    this.deviceId = 0,
    this.direction = 'download',
    this.fileName = '',
    this.fileSize = 0,
    this.bytesDone = 0,
    this.status = 'pending',
    this.speedBps = 0,
    this.error = '',
    this.startedAt,
    this.finishedAt,
  });

  final int id;
  final int sessionId;
  final int deviceId;
  final String direction;
  final String fileName;
  final int fileSize;
  final int bytesDone;
  final String status;
  final int speedBps;
  final String error;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  bool get isFailed => status == 'failed';
  bool get isSuccess => status == 'success';
  bool get isRunning => status == 'running';
  bool get isUpload => direction == 'upload';

  double get progress {
    if (fileSize <= 0) return 0;
    return (bytesDone / fileSize).clamp(0, 1).toDouble();
  }

  factory TransferRecord.fromJson(Map<String, dynamic> json) {
    return TransferRecord(
      id: asInt(json['id']),
      sessionId: asInt(json['sessionId']),
      deviceId: asInt(json['deviceId']),
      direction: asString(json['direction'], fallback: 'download'),
      fileName: asString(json['fileName']),
      fileSize: asInt(json['fileSize']),
      bytesDone: asInt(json['bytesDone']),
      status: asString(json['status'], fallback: 'pending'),
      speedBps: asInt(json['speedBps']),
      error: asString(json['error']),
      startedAt: asDate(json['startedAt']),
      finishedAt: asDate(json['finishedAt']),
    );
  }
}

class SessionMetric {
  const SessionMetric({
    this.rttMs = 0,
    this.lossRate = 0,
    this.bitrateKbps = 0,
    this.fps = 0,
    this.cpu = 0,
    this.mem = 0,
    this.netUpKbps = 0,
    this.createdAt,
  });

  final int rttMs;
  final double lossRate;
  final int bitrateKbps;
  final int fps;
  final double cpu;
  final double mem;
  final int netUpKbps;
  final DateTime? createdAt;

  factory SessionMetric.fromJson(Map<String, dynamic> json) {
    return SessionMetric(
      rttMs: asInt(json['rttMs']),
      lossRate: asDouble(json['lossRate']),
      bitrateKbps: asInt(json['bitrateKbps']),
      fps: asInt(json['fps']),
      cpu: asDouble(json['cpu']),
      mem: asDouble(json['mem']),
      netUpKbps: asInt(json['netUpKbps']),
      createdAt: asDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toReportJson() => {
        'rttMs': rttMs,
        'lossRate': lossRate,
        'bitrateKbps': bitrateKbps,
        'fps': fps,
        'cpu': cpu,
        'mem': mem,
        'netUpKbps': netUpKbps,
      };
}
