import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../data/api/auth_api.dart';
import '../data/models/bootstrap_config.dart';
import '../data/models/common.dart';
import 'settings_provider.dart';

/// 登录方式、第三方渠道、ICE、公告与协议等后台配置。
class ConfigProvider extends ChangeNotifier {
  ConfigProvider({
    required AuthApi authApi,
    required SettingsProvider settings,
    required ApiClient api,
  })  : _authApi = authApi,
        _settings = settings,
        _api = api;

  final AuthApi _authApi;
  final SettingsProvider _settings;
  final ApiClient _api;

  BootstrapConfig _config = BootstrapConfig.empty();
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;

  BootstrapConfig get config => _config;
  bool get isLoading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;

  bool get allowGuest => _config.allowGuest;
  List<ThirdPartyChannel> get loginChannels => _config.thirdPartyChannels;
  List<ThirdPartyChannel> get registerChannels => _config.appleChannels;
  bool get appleRegisterEnabled => _config.registerEnabled('apple') && _config.appleChannels.isNotEmpty;

  bool loginEnabled(String method) => _config.loginEnabled(method);
  bool registerEnabled(String method) => _config.registerEnabled(method);

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final result = await _authApi.bootstrap(platform: platform, version: '1.0.0');
      _config = result;
      _loadedOnce = true;
      final apiBase = _config.apiBaseUrl;
      final signaling = _config.signalingUrl;
      if (apiBase.isNotEmpty || signaling.isNotEmpty) {
        await _settings.applyServerEndpoints(
          apiBaseUrl: apiBase,
          signalingUrl: signaling,
        );
      }
      await _settings.setInt(
        SettingsKeys.lanDiscoveryPort,
        _config.lanDiscoveryPort,
      );
      _api.updateBaseUrl(_settings.resolvedApiBaseUrl);
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
