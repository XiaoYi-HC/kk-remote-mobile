import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/storage/local_store.dart';

/// 本地设置与开发环境地址覆盖。
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._store);

  final LocalStore _store;
  bool _unlockedThisSession = false;

  bool get unlockedThisSession => _unlockedThisSession;
  set unlockedThisSession(bool value) {
    _unlockedThisSession = value;
    notifyListeners();
  }

  bool getBool(String key, {bool fallback = false}) =>
      _store.getBool(key) ?? fallback;

  int getInt(String key, {int fallback = 0}) => _store.getInt(key) ?? fallback;

  double getDouble(String key, {double fallback = 0}) =>
      _store.getDouble(key) ?? fallback;

  String getString(String key, {String fallback = ''}) =>
      _store.getString(key) ?? fallback;

  List<String> getList(String key) => _store.getStringList(key);

  Map<String, dynamic> getMapOverride(String key) => _store.getMap(key);

  Future<void> setBool(String key, bool value) async {
    await _store.setBool(key, value);
    notifyListeners();
  }

  Future<void> setInt(String key, int value) async {
    await _store.setInt(key, value);
    notifyListeners();
  }

  Future<void> setDouble(String key, double value) async {
    await _store.setDouble(key, value);
    notifyListeners();
  }

  Future<void> setString(String key, String value) async {
    await _store.setString(key, value);
    notifyListeners();
  }

  Future<void> setList(String key, List<String> value) async {
    await _store.setStringList(key, value);
    notifyListeners();
  }

  Future<void> setMapValue(String key, Map<String, dynamic> value) async {
    await _store.setMap(key, value);
    notifyListeners();
  }

  Future<void> remove(String key) async {
    await _store.remove(key);
    notifyListeners();
  }

  String get apiBaseUrlOverride => getString(SettingsKeys.apiOverride);
  String get signalingUrlOverride => getString(SettingsKeys.signalingOverride);
  String get serverApiBaseUrl => getString(SettingsKeys.serverApiBaseUrl);
  String get serverSignalingUrl => getString(SettingsKeys.serverSignalingUrl);

  String get resolvedApiBaseUrl {
    if (apiBaseUrlOverride.trim().isNotEmpty) return apiBaseUrlOverride.trim();
    if (serverApiBaseUrl.isNotEmpty) return serverApiBaseUrl;
    return AppConstants.defaultApiBaseUrl;
  }

  String get resolvedSignalingUrl {
    if (signalingUrlOverride.trim().isNotEmpty) return signalingUrlOverride.trim();
    if (serverSignalingUrl.isNotEmpty) return serverSignalingUrl;
    return AppConstants.defaultSignalingUrl;
  }

  /// 后台下发的是站点根地址（如 http://host:8080），客户端 API 统一挂在 /api/v1。
  static String normalizeApiBaseUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return value;
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      final path = uri.path;
      if (!path.endsWith('/api/v1')) {
        value = '$value/api/v1';
      }
    } else if (!value.endsWith('/api/v1')) {
      value = '$value/api/v1';
    }
    return value;
  }

  /// 由 bootstrap 下发的服务地址，仅在未手动覆盖时生效。
  Future<void> applyServerEndpoints({required String apiBaseUrl, required String signalingUrl}) async {
    var changed = false;
    final normalizedApi = normalizeApiBaseUrl(apiBaseUrl);
    if (normalizedApi.isNotEmpty && normalizedApi != serverApiBaseUrl) {
      await _store.setString(SettingsKeys.serverApiBaseUrl, normalizedApi);
      changed = true;
    }
    if (signalingUrl.isNotEmpty && signalingUrl != serverSignalingUrl) {
      await _store.setString(SettingsKeys.serverSignalingUrl, signalingUrl);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  String get qualityPreset => getString(SettingsKeys.qualityPreset, fallback: 'hd');
  double get resolutionScale => getDouble(SettingsKeys.resolutionScale, fallback: 1.0);
  int get fpsLimit => getInt(SettingsKeys.fpsLimit, fallback: 60);
  int get bitrateLimit => getInt(SettingsKeys.bitrateLimit, fallback: 0);
  String get encoder => getString(SettingsKeys.encoder, fallback: 'auto');
  bool get adaptiveQuality => getBool(SettingsKeys.adaptiveQuality, fallback: true);
  bool get keepScreenOn => getBool(SettingsKeys.keepScreenOn, fallback: true);
  double get fontScale => getDouble(SettingsKeys.fontScale, fallback: 1.0);
  double get uiScale => getDouble(SettingsKeys.uiScale, fallback: 1.0);
  double get effectiveTextScale => (fontScale * uiScale).clamp(0.8, 1.8).toDouble();
  String get orientationLock => getString(SettingsKeys.orientationLock, fallback: 'auto');

  bool get audioEnabled => getBool(SettingsKeys.audioEnabled, fallback: true);
  double get volume => getDouble(SettingsKeys.volume, fallback: 1.0);
  bool get micPassthrough => getBool(SettingsKeys.micPassthrough);

  String get touchMode => getString(SettingsKeys.touchMode, fallback: 'touch');
  double get touchSensitivity =>
      getDouble(SettingsKeys.touchSensitivity, fallback: 1.0);
  double get scrollSensitivity =>
      getDouble(SettingsKeys.scrollSensitivity, fallback: 1.0);
  double get gestureSensitivity =>
      getDouble(SettingsKeys.gestureSensitivity, fallback: 1.0);
  bool get trackballMode => getBool(SettingsKeys.trackballMode);
  bool get threeFingerEnabled =>
      getBool(SettingsKeys.threeFingerEnabled, fallback: true);
  bool get hapticsEnabled => getBool(SettingsKeys.hapticsEnabled, fallback: true);
  bool get hideCursor => getBool(SettingsKeys.hideCursor);
  List<String> get hotkeyFavorites => getList(SettingsKeys.hotkeyFavorites);

  bool get autoReconnect => getBool(SettingsKeys.autoReconnect, fallback: true);
  int get reconnectInterval =>
      getInt(SettingsKeys.reconnectInterval, fallback: 3);
  bool get networkHint => getBool(SettingsKeys.networkHint, fallback: true);
  int get trafficReminderMb =>
      getInt(SettingsKeys.trafficReminderMb, fallback: 500);
  bool get p2pPreferred => getBool(SettingsKeys.p2pPreferred, fallback: true);
  bool get allowRelay => getBool(SettingsKeys.allowRelay, fallback: true);
  bool get onlyWifi => getBool(SettingsKeys.onlyWifi);
  bool get saveDataMode => getBool(SettingsKeys.saveDataMode);
  bool get lowBandwidthAdaptive =>
      getBool(SettingsKeys.lowBandwidthAdaptive, fallback: true);
  int get minBitrate => getInt(SettingsKeys.minBitrate, fallback: 300);
  int get restoreThreshold =>
      getInt(SettingsKeys.restoreThreshold, fallback: 800);

  bool get backgroundKeepAlive =>
      getBool(SettingsKeys.backgroundKeepAlive, fallback: true);
  bool get notificationEnabled =>
      getBool(SettingsKeys.notificationEnabled, fallback: true);
  bool get incomingCallPush =>
      getBool(SettingsKeys.incomingCallPush, fallback: true);

  bool get clipboardSync => getBool(SettingsKeys.clipboardSync, fallback: true);
  bool get appLockEnabled => getBool(SettingsKeys.appLockEnabled);
  bool get biometricEnabled =>
      getBool(SettingsKeys.biometricEnabled, fallback: true);
  bool get cloudSync => getBool(SettingsKeys.cloudSync, fallback: true);

  String get language => getString(SettingsKeys.language, fallback: 'zh-CN');
  bool get accessibilityGuideSeen => getBool(SettingsKeys.accessibilityGuideSeen);
  bool get protocolAgreed => getBool(SettingsKeys.protocolAgreed);

  String get downloadDir => getString(SettingsKeys.downloadDir);
}
