import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../../data/models/common.dart';
import 'host_models.dart';

/// 移动端被控（屏幕共享）相关接口。
///
/// 设备注册与验证码刷新使用独立的 ApiClient，避免覆盖当前登录用户的 access token。
class HostApi {
  HostApi({required String baseUrl}) : _api = ApiClient(baseUrl: baseUrl);

  final ApiClient _api;

  static String get platform => Platform.isIOS ? 'ios' : 'android';

  void setDeviceToken(String? token) => _api.setToken(token);

  Future<HostRegistration> register({
    required String deviceUuid,
    required String name,
    required String osVersion,
    String model = '',
    String? deviceSecret,
  }) async {
    final data = await _api.post('/client/agent/register', data: {
      'deviceUuid': deviceUuid,
      'name': name,
      'platform': platform,
      'osVersion': osVersion,
      'model': model,
      'appVersion': AppConstants.appVersion,
      if (deviceSecret != null && deviceSecret.isNotEmpty) 'deviceSecret': deviceSecret,
      'capabilities': {
        'screen': true,
        'microphone': true,
        'camera': false,
        'control': false,
      },
      'settings': {
        'confirmEnabled': true,
        'viewOnly': true,
      },
    });
    return HostRegistration.fromJson(asMap(data));
  }

  Future<(String, int)> refreshVerificationCode() async {
    final data = await _api.post('/client/agent/verification-code/refresh');
    final map = asMap(data);
    return (asString(map['verificationCode']), asInt(map['verificationExpiresAt']));
  }

  Future<List<IceServerConfig>> iceServers() async {
    try {
      final data = await _api.get('/client/config/bootstrap', query: {
        'platform': platform,
        'version': AppConstants.appVersion,
      });
      final map = asMap(data);
      return asList(map['iceServers'])
          .map((item) => IceServerConfig.fromJson(asMap(item)))
          .where((item) => item.urls.isNotEmpty)
          .toList();
    } catch (_) {
      // 获取失败时退回公共 STUN，仍可尝试直连。
      return const [
        IceServerConfig(urls: ['stun:stun.l.google.com:19302']),
      ];
    }
  }
}
