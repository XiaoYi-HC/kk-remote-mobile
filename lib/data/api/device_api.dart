import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/device.dart';
import '../models/session.dart';

class DeviceApi {
  DeviceApi(this._api);

  final ApiClient _api;

  Future<DeviceListResult> list({
    String? keyword,
    int? groupId,
    bool? favorite,
  }) async {
    final data = await _api.get('/client/devices', query: {
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (groupId != null && groupId > 0) 'groupId': groupId,
      if (favorite == true) 'favorite': 'true',
    });
    return DeviceListResult.fromJson(asMap(data));
  }

  Future<Device> bind({
    required String deviceCode,
    String? verifyCode,
    String? password,
    String? remark,
  }) async {
    final data = await _api.post('/client/devices-bind', data: {
      'deviceCode': deviceCode,
      if (verifyCode != null && verifyCode.isNotEmpty) 'verifyCode': verifyCode,
      if (password != null && password.isNotEmpty) 'password': password,
      if (remark != null && remark.isNotEmpty) 'remark': remark,
    });
    return Device.fromJson(asMap(data));
  }

  Future<Device> update(
    int id, {
    String? remark,
    int? groupId,
    bool? favorite,
    bool? alertOffline,
    bool? wolEnabled,
  }) async {
    final data = await _api.put('/client/devices/$id', data: {
      if (remark != null) 'remark': remark,
      if (groupId != null) 'groupId': groupId,
      if (favorite != null) 'favorite': favorite,
      if (alertOffline != null) 'alertOffline': alertOffline,
      if (wolEnabled != null) 'wolEnabled': wolEnabled,
    });
    return Device.fromJson(asMap(data));
  }

  Future<void> unbind(int id) async {
    await _api.delete('/client/devices/$id');
  }

  Future<DeviceDetail> detail(int id) async {
    final data = await _api.get('/client/devices/$id');
    return DeviceDetail.fromJson(asMap(data));
  }

  Future<List<SessionRecord>> sessions(int id, {int page = 1, int pageSize = 20}) async {
    final data = await _api.get('/client/devices/$id/sessions', query: {
      'page': page,
      'pageSize': pageSize,
    });
    return asList(asMap(data)['list'])
        .map((item) => SessionRecord.fromJson(asMap(item)))
        .toList();
  }

  Future<List<DeviceAccessRule>> accessRules(int id) async {
    final data = await _api.get('/client/devices/$id/access-rules');
    return asList(data).map((item) => DeviceAccessRule.fromJson(asMap(item))).toList();
  }

  Future<DeviceAccessRule> createAccessRule(
    int id, {
    required String ruleType,
    int? controllerUserId,
    String? controllerDeviceCode,
    String? remark,
  }) async {
    final data = await _api.post('/client/devices/$id/access-rules', data: {
      'ruleType': ruleType,
      if (controllerUserId != null && controllerUserId > 0) 'controllerUserId': controllerUserId,
      if (controllerDeviceCode != null && controllerDeviceCode.isNotEmpty)
        'controllerDeviceCode': controllerDeviceCode,
      if (remark != null) 'remark': remark,
    });
    return DeviceAccessRule.fromJson(asMap(data));
  }

  Future<void> deleteAccessRule(int id, int ruleId) async {
    await _api.delete('/client/devices/$id/access-rules/$ruleId');
  }

  Future<Map<String, dynamic>> settings(int id) async {
    final data = await _api.get('/client/devices/$id/settings');
    return asMap(data);
  }

  Future<Map<String, dynamic>> updateSettings(int id, Map<String, dynamic> settings) async {
    final data = await _api.put('/client/devices/$id/settings', data: settings);
    return asMap(data);
  }

  Future<Map<String, dynamic>> wakeOnLan(int id) async {
    final data = await _api.post('/client/devices/$id/wol');
    return asMap(data);
  }

  Future<List<DeviceGroup>> groups() async {
    final data = await _api.get('/client/device-groups');
    return asList(data).map((item) => DeviceGroup.fromJson(asMap(item))).toList();
  }

  Future<DeviceGroup> createGroup(String name) async {
    final data = await _api.post('/client/device-groups', data: {'name': name});
    return DeviceGroup.fromJson(asMap(data));
  }

  Future<void> updateGroup(int id, {String? name, int? sort}) async {
    await _api.put('/client/device-groups/$id', data: {
      if (name != null) 'name': name,
      if (sort != null) 'sort': sort,
    });
  }

  Future<void> deleteGroup(int id) async {
    await _api.delete('/client/device-groups/$id');
  }

  Future<Map<String, dynamic>> pullSync() async {
    final data = await _api.get('/client/devices-sync');
    return asMap(data);
  }

  Future<void> pushSync(List<Map<String, dynamic>> items, {String? updatedAt}) async {
    await _api.post('/client/devices-sync', data: {
      'items': items,
      if (updatedAt != null) 'updatedAt': updatedAt,
    });
  }
}
