import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json_utils.dart';
import '../../../data/api/device_api.dart';
import '../../../data/lan/lan_discovery_service.dart';
import '../../../data/models/device.dart';
import '../../../state/app_services.dart';
import '../../../state/settings_provider.dart';

class DevicesProvider extends ChangeNotifier {
  DevicesProvider({
    required DeviceApi api,
    required SettingsProvider settings,
    required LanDiscoveryService lanDiscovery,
    required AppServices services,
  })  : _api = api,
        _settings = settings,
        _lan = lanDiscovery,
        _services = services {
    _lanSub = _lan.devices.listen((list) {
      lanDevices = list;
      notifyListeners();
    });
    _services.notifications.onIncomingCallAction = _handleNotificationAction;
  }

  final DeviceApi _api;
  final SettingsProvider _settings;
  final LanDiscoveryService _lan;
  final AppServices _services;

  StreamSubscription<List<LanDevice>>? _lanSub;

  List<Device> devices = [];
  List<DeviceGroup> groups = [];
  List<LanDevice> lanDevices = [];
  bool loading = false;
  bool refreshing = false;
  bool lanScanning = false;
  String? error;
  String keyword = '';
  int? groupId;
  bool favoriteOnly = false;

  Device? incomingCall;
  bool incomingAcceptRequested = false;
  String incomingSource = '';
  int _loadSeq = 0;

  /// 退出登录时清空账号相关数据，避免下一个账号看到上一个账号的设备。
  void resetForLogout() {
    _loadSeq++;
    devices = [];
    groups = [];
    lanDevices = [];
    keyword = '';
    groupId = null;
    favoriteOnly = false;
    loading = false;
    refreshing = false;
    lanScanning = false;
    error = null;
    incomingCall = null;
    incomingAcceptRequested = false;
    incomingSource = '';
    // 本地覆盖（备注/收藏/分组）属于账号数据，一并清理。
    unawaited(_settings.setMapValue('device_local_overrides', const {}));
    notifyListeners();
  }

  List<Device> get visibleDevices {
    var list = List<Device>.from(devices);
    if (favoriteOnly) list = list.where((item) => item.favorite).toList();
    if (groupId != null && groupId! > 0) {
      list = list.where((item) => item.groupId == groupId).toList();
    }
    final kw = keyword.trim().toLowerCase();
    if (kw.isNotEmpty) {
      list = list.where((item) {
        return item.displayName.toLowerCase().contains(kw) ||
            item.deviceCode.toLowerCase().contains(kw) ||
            item.groupName.toLowerCase().contains(kw);
      }).toList();
    }
    list.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      if (a.online != b.online) return a.online ? -1 : 1;
      return a.displayName.compareTo(b.displayName);
    });
    return list;
  }

  List<Device> get favoriteDevices => devices.where((item) => item.favorite).toList();

  Future<void> load({bool silent = false}) async {
    final seq = ++_loadSeq;
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final result = await _api.list();
      if (seq != _loadSeq) return;
      devices = result.devices.map(_applyLocalOverride).toList();
      groups = result.groups;
      if (groups.isEmpty) {
        try {
          final fetched = await _api.groups();
          if (seq != _loadSeq) return;
          groups = fetched;
        } catch (_) {
          // 分组接口抖动时保留本地已有分组，避免筛选条突然消失。
        }
      }
      error = null;
    } on ApiException catch (e) {
      if (seq == _loadSeq) error = e.message;
    } finally {
      // 旧请求不能覆盖新请求的 loading 状态。
      if (seq == _loadSeq) {
        loading = false;
        refreshing = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    await load(silent: true);
  }

  void setKeyword(String value) {
    keyword = value;
    notifyListeners();
  }

  void setGroup(int? id) {
    groupId = id;
    notifyListeners();
  }

  void toggleFavoriteFilter() {
    favoriteOnly = !favoriteOnly;
    notifyListeners();
  }

  Device _applyLocalOverride(Device device) {
    final overrides = _settings.getMapOverride('device_local_overrides');
    final entry = asMap(overrides[device.deviceCode.toString()]);
    if (entry.isEmpty) return device;
    return device.copyWith(
      remark: asString(entry['remark'], fallback: device.remark),
      favorite: asBool(entry['favorite'], fallback: device.favorite),
      groupId: asInt(entry['groupId'], fallback: device.groupId),
      groupName: asString(entry['groupName'], fallback: device.groupName),
    );
  }

  Future<void> _saveLocalOverride(Device device) async {
    final overrides = Map<String, dynamic>.from(_settings.getMapOverride('device_local_overrides'));
    overrides[device.deviceCode] = {
      'remark': device.remark,
      'favorite': device.favorite,
      'groupId': device.groupId,
      'groupName': device.groupName,
    };
    await _settings.setMapValue('device_local_overrides', overrides);
  }

  Future<void> toggleFavorite(Device device) async {
    final updated = device.copyWith(favorite: !device.favorite);
    _replace(updated);
    if (!_settings.cloudSync) {
      await _saveLocalOverride(updated);
      return;
    }
    try {
      final result = await _api.update(device.id, favorite: updated.favorite);
      _replace(result);
    } catch (error) {
      _replace(device);
      rethrow;
    }
  }

  Future<void> updateRemark(Device device, String remark) async {
    final updated = device.copyWith(remark: remark);
    _replace(updated);
    if (!_settings.cloudSync) {
      await _saveLocalOverride(updated);
      return;
    }
    try {
      final result = await _api.update(device.id, remark: remark);
      _replace(result);
    } catch (error) {
      _replace(device);
      rethrow;
    }
  }

  Future<void> updateGroup(Device device, DeviceGroup? group) async {
    final updated = device.copyWith(
      groupId: group?.id ?? 0,
      groupName: group?.name ?? '',
    );
    _replace(updated);
    if (!_settings.cloudSync) {
      await _saveLocalOverride(updated);
      return;
    }
    try {
      final result = await _api.update(device.id, groupId: updated.groupId);
      _replace(result);
    } catch (error) {
      _replace(device);
      rethrow;
    }
  }

  Future<Device> bindDevice({
    required String deviceCode,
    String? verifyCode,
    String? password,
  }) async {
    final device = await _api.bind(
      deviceCode: deviceCode,
      verifyCode: verifyCode,
      password: password,
    );
    _replace(device);
    await load(silent: true);
    return device;
  }

  Future<void> unbind(Device device) async {
    await _api.unbind(device.id);
    devices = devices.where((item) => item.id != device.id).toList();
    notifyListeners();
  }

  void _replace(Device device) {
    final index = devices.indexWhere((item) => item.id == device.id);
    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.insert(0, device);
    }
    notifyListeners();
  }

  Future<DeviceGroup> createGroup(String name) async {
    final group = await _api.createGroup(name);
    groups = [...groups, group];
    notifyListeners();
    return group;
  }

  Future<void> startLanScan() async {
    if (lanScanning) return;
    lanScanning = true;
    lanDevices = [];
    notifyListeners();
    await _lan.start(port: _settings.getInt(SettingsKeys.lanDiscoveryPort, fallback: 38401));
    lanScanning = _lan.isScanning;
    notifyListeners();
    Future<void>.delayed(const Duration(seconds: 9), () {
      if (lanScanning) {
        stopLanScan();
      }
    });
  }

  Future<void> stopLanScan() async {
    await _lan.stop();
    lanScanning = false;
    notifyListeners();
  }

  void _handleNotificationAction(Map<String, dynamic> payload) {
    if (payload['type'] != 'incoming_call') return;
    final accepted = payload['accepted'];
    if (accepted == false) {
      incomingCall = null;
      notifyListeners();
      return;
    }
    incomingCall = Device(
      name: asString(payload['deviceName']),
      deviceCode: asString(payload['deviceCode']),
      online: true,
    );
    incomingSource = asString(payload['source'], fallback: 'push');
    incomingAcceptRequested = accepted == true;
    notifyListeners();
  }

  void showIncomingCall(Device device, {String source = 'signaling'}) {
    incomingCall = device;
    incomingSource = source;
    incomingAcceptRequested = false;
    notifyListeners();
  }

  void acceptIncoming() {
    incomingAcceptRequested = true;
    notifyListeners();
  }

  void dismissIncoming() {
    incomingCall = null;
    incomingAcceptRequested = false;
    notifyListeners();
  }

  void consumeIncomingAccept() {
    incomingAcceptRequested = false;
    incomingCall = null;
    notifyListeners();
  }

  Future<void> simulateIncomingCall(Device device) async {
    showIncomingCall(device, source: 'push');
    await _services.notifications.showIncomingCall(
      deviceName: device.displayName,
      deviceCode: device.deviceCode,
    );
  }

  @override
  void dispose() {
    _lanSub?.cancel();
    super.dispose();
  }
}
