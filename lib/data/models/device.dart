import 'dart:convert';

import '../../core/utils/json_utils.dart';
import 'session.dart';

class Device {
  const Device({
    this.id = 0,
    this.deviceCode = '',
    this.name = '',
    this.platform = '',
    this.osVersion = '',
    this.model = '',
    this.status = 'offline',
    this.online = false,
    this.lastOnlineAt,
    this.groupId = 0,
    this.groupName = '',
    this.remark = '',
    this.favorite = false,
    this.alertOffline = false,
    this.wolEnabled = false,
    this.appVersion = '',
    this.natType = '',
    this.publicIp = '',
    this.region = '',
    this.blacklisted = false,
    this.lastSessionId = '',
    this.createdAt,
    this.lan = false,
  });

  final int id;
  final String deviceCode;
  final String name;
  final String platform;
  final String osVersion;
  final String model;
  final String status;
  final bool online;
  final DateTime? lastOnlineAt;
  final int groupId;
  final String groupName;
  final String remark;
  final bool favorite;
  final bool alertOffline;
  final bool wolEnabled;
  final String appVersion;
  final String natType;
  final String publicIp;
  final String region;
  final bool blacklisted;
  final String lastSessionId;
  final DateTime? createdAt;

  /// 局域网发现得到的设备不在服务端台账中。
  final bool lan;

  String get displayName {
    if (remark.isNotEmpty) return remark;
    if (name.isNotEmpty) return name;
    return '未命名设备';
  }

  String get platformLabel {
    switch (platform.toLowerCase()) {
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
        return platform.isEmpty ? '桌面设备' : platform;
    }
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: asInt(json['id']),
      deviceCode: asString(json['deviceCode']),
      name: asString(json['name']),
      platform: asString(json['platform']),
      osVersion: asString(json['osVersion']),
      model: asString(json['model']),
      status: asString(json['status'], fallback: 'offline'),
      online: asBool(json['online']),
      lastOnlineAt: asDate(json['lastOnlineAt']),
      groupId: asInt(json['groupId']),
      groupName: asString(json['groupName']),
      remark: asString(json['remark']),
      favorite: asBool(json['favorite']),
      alertOffline: asBool(json['alertOffline']),
      wolEnabled: asBool(json['wolEnabled']),
      appVersion: asString(json['appVersion']),
      natType: asString(json['natType']),
      publicIp: asString(json['publicIp']),
      region: asString(json['region']),
      blacklisted: asBool(json['blacklisted']),
      lastSessionId: asString(json['lastSessionId']),
      createdAt: asDate(json['createdAt']),
    );
  }

  Device copyWith({
    String? remark,
    int? groupId,
    String? groupName,
    bool? favorite,
    bool? alertOffline,
    bool? online,
    bool? lan,
  }) {
    return Device(
      id: id,
      deviceCode: deviceCode,
      name: name,
      platform: platform,
      osVersion: osVersion,
      model: model,
      status: status,
      online: online ?? this.online,
      lastOnlineAt: lastOnlineAt,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      remark: remark ?? this.remark,
      favorite: favorite ?? this.favorite,
      alertOffline: alertOffline ?? this.alertOffline,
      wolEnabled: wolEnabled,
      appVersion: appVersion,
      natType: natType,
      publicIp: publicIp,
      region: region,
      blacklisted: blacklisted,
      lastSessionId: lastSessionId,
      createdAt: createdAt,
      lan: lan ?? this.lan,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceCode': deviceCode,
        'name': name,
        'platform': platform,
        'osVersion': osVersion,
        'model': model,
        'status': status,
        'online': online,
        'lastOnlineAt': lastOnlineAt?.toIso8601String(),
        'groupId': groupId,
        'groupName': groupName,
        'remark': remark,
        'favorite': favorite,
        'alertOffline': alertOffline,
        'wolEnabled': wolEnabled,
        'appVersion': appVersion,
        'natType': natType,
        'publicIp': publicIp,
        'region': region,
        'blacklisted': blacklisted,
        'lastSessionId': lastSessionId,
        'createdAt': createdAt?.toIso8601String(),
        'lan': lan,
      };
}

class DeviceGroup {
  const DeviceGroup({required this.id, required this.name, this.sort = 0});

  final int id;
  final String name;
  final int sort;

  factory DeviceGroup.fromJson(Map<String, dynamic> json) {
    return DeviceGroup(
      id: asInt(json['id']),
      name: asString(json['name']),
      sort: asInt(json['sort']),
    );
  }
}

class DeviceAccessRule {
  const DeviceAccessRule({
    this.id = 0,
    this.ruleType = 'allow',
    this.controllerUserId = 0,
    this.controllerDeviceCode = '',
    this.remark = '',
  });

  final int id;
  final String ruleType;
  final int controllerUserId;
  final String controllerDeviceCode;
  final String remark;

  factory DeviceAccessRule.fromJson(Map<String, dynamic> json) {
    return DeviceAccessRule(
      id: asInt(json['id']),
      ruleType: asString(json['ruleType'], fallback: 'allow'),
      controllerUserId: asInt(json['controllerUserId']),
      controllerDeviceCode: asString(json['controllerDeviceCode']),
      remark: asString(json['remark']),
    );
  }
}

class DeviceDetail {
  const DeviceDetail({
    this.device,
    this.settings = const {},
    this.accessRules = const [],
    this.recentSessions = const [],
  });

  final Device? device;
  final Map<String, dynamic> settings;
  final List<DeviceAccessRule> accessRules;
  final List<SessionRecord> recentSessions;

  factory DeviceDetail.fromJson(Map<String, dynamic> json) {
    return DeviceDetail(
      device: json['device'] is Map ? Device.fromJson(asMap(json['device'])) : null,
      settings: asMap(json['settings']),
      accessRules: asList(json['accessRules'])
          .map((item) => DeviceAccessRule.fromJson(asMap(item)))
          .toList(),
      recentSessions: asList(json['recentSessions'])
          .map((item) => SessionRecord.fromJson(asMap(item)))
          .toList(),
    );
  }
}

class DeviceListResult {
  const DeviceListResult({this.devices = const [], this.groups = const []});

  final List<Device> devices;
  final List<DeviceGroup> groups;

  factory DeviceListResult.fromJson(Map<String, dynamic> json) {
    return DeviceListResult(
      devices: asList(json['list']).map((item) => Device.fromJson(asMap(item))).toList(),
      groups: asList(json['groups']).map((item) => DeviceGroup.fromJson(asMap(item))).toList(),
    );
  }
}

/// 局域网 UDP 广播发现的设备。
class LanDevice {
  const LanDevice({
    required this.name,
    required this.deviceCode,
    required this.ip,
    this.port = 0,
    this.platform = 'windows',
    this.osVersion = '',
    this.model = '',
    this.online = true,
    this.lastSeen,
  });

  final String name;
  final String deviceCode;
  final String ip;
  final int port;
  final String platform;
  final String osVersion;
  final String model;
  final bool online;
  final DateTime? lastSeen;

  String get displayName => name.isEmpty ? deviceCode : name;

  static LanDevice? tryParse(String raw, String ip) {
    if (raw.isEmpty) return null;
    try {
      final json = asMap(jsonDecode(raw));
      if (asString(json['magic']) != 'KKREMOTE_LAN_V1' &&
          asString(json['type']) != 'kkremote.device') {
        return null;
      }
      final code = asString(json['deviceCode']);
      if (code.isEmpty) return null;
      return LanDevice(
        name: asString(json['name']),
        deviceCode: code,
        ip: asString(json['ip'], fallback: ip),
        port: asInt(json['port']),
        platform: asString(json['platform'], fallback: 'windows'),
        osVersion: asString(json['osVersion']),
        model: asString(json['model']),
        online: asBool(json['online'], fallback: true),
        lastSeen: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'magic': 'KKREMOTE_LAN_V1',
        'type': 'kkremote.device',
        'name': name,
        'deviceCode': deviceCode,
        'ip': ip,
        'port': port,
        'platform': platform,
        'osVersion': osVersion,
        'model': model,
        'online': online,
      };
}
