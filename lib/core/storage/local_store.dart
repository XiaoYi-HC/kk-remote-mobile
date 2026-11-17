import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 本地设置与缓存，仅保存偏好、令牌和离线缓存，不保存业务假数据。
class LocalStore {
  LocalStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore._(prefs);
  }

  String? getString(String key) => _prefs.getString(key);

  bool? getBool(String key) => _prefs.getBool(key);

  int? getInt(String key) => _prefs.getInt(key);

  double? getDouble(String key) => _prefs.getDouble(key);

  List<String> getStringList(String key) => _prefs.getStringList(key) ?? const [];

  Map<String, dynamic> getMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final value = jsonDecode(raw);
      return value is Map ? value.cast<String, dynamic>() : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> setString(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  Future<void> setDouble(String key, double value) => _prefs.setDouble(key, value);

  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  Future<void> setMap(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> clearAll() => _prefs.clear();
}
