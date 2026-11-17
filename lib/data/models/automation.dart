import '../../core/utils/json_utils.dart';

class ScheduledTask {
  const ScheduledTask({
    this.id = 0,
    this.deviceId = 0,
    this.name = '',
    this.triggerAt,
    this.repeatRule = 'none',
    this.retry = false,
    this.enabled = true,
    this.lastRunAt,
    this.lastResult = '',
  });

  final int id;
  final int deviceId;
  final String name;
  final DateTime? triggerAt;
  final String repeatRule;
  final bool retry;
  final bool enabled;
  final DateTime? lastRunAt;
  final String lastResult;

  factory ScheduledTask.fromJson(Map<String, dynamic> json) {
    return ScheduledTask(
      id: asInt(json['id']),
      deviceId: asInt(json['deviceId']),
      name: asString(json['name']),
      triggerAt: asDate(json['triggerAt']),
      repeatRule: asString(json['repeatRule'], fallback: 'none'),
      retry: asBool(json['retry']),
      enabled: asBool(json['enabled'], fallback: true),
      lastRunAt: asDate(json['lastRunAt']),
      lastResult: asString(json['lastResult']),
    );
  }

  Map<String, dynamic> toRequest() => {
        'deviceId': deviceId,
        'name': name,
        'triggerAt': (triggerAt ?? DateTime.now()).toUtc().toIso8601String(),
        'repeatRule': repeatRule,
        'retry': retry,
        'enabled': enabled,
      };
}

class OfflineCommand {
  const OfflineCommand({
    this.id = 0,
    this.deviceId = 0,
    this.command = '',
    this.enabled = true,
    this.lastRunAt,
    this.lastResult = '',
  });

  final int id;
  final int deviceId;
  final String command;
  final bool enabled;
  final DateTime? lastRunAt;
  final String lastResult;

  factory OfflineCommand.fromJson(Map<String, dynamic> json) {
    return OfflineCommand(
      id: asInt(json['id']),
      deviceId: asInt(json['deviceId']),
      command: asString(json['command']),
      enabled: asBool(json['enabled'], fallback: true),
      lastRunAt: asDate(json['lastRunAt']),
      lastResult: asString(json['lastResult']),
    );
  }
}

class OfflineCommandResult {
  const OfflineCommandResult({
    this.id = 0,
    this.commandId = 0,
    this.deviceId = 0,
    this.success = false,
    this.output = '',
    this.error = '',
    this.executedAt,
  });

  final int id;
  final int commandId;
  final int deviceId;
  final bool success;
  final String output;
  final String error;
  final DateTime? executedAt;

  factory OfflineCommandResult.fromJson(Map<String, dynamic> json) {
    return OfflineCommandResult(
      id: asInt(json['id']),
      commandId: asInt(json['commandId']),
      deviceId: asInt(json['deviceId']),
      success: asBool(json['success']),
      output: asString(json['output']),
      error: asString(json['error']),
      executedAt: asDate(json['executedAt']),
    );
  }
}

class NetworkDiagnosticsConfig {
  const NetworkDiagnosticsConfig({
    this.iceServers = const [],
    this.turnTtlSeconds = 600,
    this.lanDiscoveryPort = 38401,
    this.signalingUrl = '',
  });

  final List<Map<String, dynamic>> iceServers;
  final int turnTtlSeconds;
  final int lanDiscoveryPort;
  final String signalingUrl;

  factory NetworkDiagnosticsConfig.fromJson(Map<String, dynamic> json) {
    return NetworkDiagnosticsConfig(
      iceServers: asList(json['iceServers']).map(asMap).toList(),
      turnTtlSeconds: asInt(json['turnTtlSeconds'], fallback: 600),
      lanDiscoveryPort: asInt(json['lanDiscoveryPort'], fallback: 38401),
      signalingUrl: asString(json['signalingUrl']),
    );
  }
}
