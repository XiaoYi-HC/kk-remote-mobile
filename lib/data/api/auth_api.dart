import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/bootstrap_config.dart';
import '../models/user.dart';

class AuthApi {
  AuthApi(this._api);

  final ApiClient _api;

  Future<BootstrapConfig> bootstrap({required String platform, String? version}) async {
    final data = await _api.get('/client/config/bootstrap', query: {
      'platform': platform,
      if (version != null && version.isNotEmpty) 'version': version,
    });
    return BootstrapConfig.fromJson(asMap(data));
  }

  Future<BootstrapConfig> platformBootstrap(String platform) =>
      bootstrap(platform: platform, version: '1.0.0');

  Future<void> sendSms({required String phone, required String scene}) async {
    await _api.post('/client/auth/sms/send', data: {'phone': phone, 'scene': scene});
  }

  Future<void> sendEmail({required String email, required String scene}) async {
    await _api.post('/client/auth/email/send', data: {'email': email, 'scene': scene});
  }

  Future<LoginResult> login({
    required String method,
    required String account,
    String? password,
    String? code,
  }) async {
    final data = await _api.post('/client/auth/login', data: {
      'method': method,
      'account': account,
      if (password != null) 'password': password,
      if (code != null) 'code': code,
      'client': 'mobile',
    });
    return LoginResult.fromJson(asMap(data));
  }

  Future<LoginResult> register({
    required String method,
    required String phone,
    required String email,
    required String code,
    required String password,
    String? inviteCode,
  }) async {
    final data = await _api.post('/client/auth/register', data: {
      'method': method,
      'phone': phone,
      'email': email,
      'code': code,
      'password': password,
      if (inviteCode != null && inviteCode.isNotEmpty) 'inviteCode': inviteCode,
      'client': 'mobile',
    });
    return LoginResult.fromJson(asMap(data));
  }

  Future<LoginResult> guest() async {
    final data = await _api.post('/client/auth/guest');
    return LoginResult.fromJson(asMap(data));
  }

  Future<void> forgotPassword({
    required String account,
    required String code,
    required String newPassword,
  }) async {
    await _api.post('/client/auth/forgot-password', data: {
      'account': account,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<LoginResult> verify2fa({required String ticket, required String code}) async {
    final data = await _api.post('/client/auth/2fa/verify', data: {
      'ticket': ticket,
      'code': code,
      'client': 'mobile',
    });
    return LoginResult.fromJson(asMap(data));
  }

  /// 使用 refresh token 换取新的 access token（不参与自动刷新，避免递归）。
  Future<LoginResult> refresh(String refreshToken) async {
    final data = await _api.postWithoutRetry('/client/auth/refresh', data: {
      'refreshToken': refreshToken,
      'client': 'mobile',
    });
    return LoginResult.fromJson(asMap(data));
  }

  Future<void> logout({String? refreshToken}) async {
    await _api.post('/client/auth/logout', data: {
      if (refreshToken != null) 'refreshToken': refreshToken,
    });
  }

  Future<Map<String, dynamic>> oauthUrl(String provider) async {
    final data = await _api.post('/client/auth/oauth/$provider/url', data: {
      'client': 'mobile',
    });
    return asMap(data);
  }

  Future<LoginResult> oauthCallback({
    required String provider,
    required String code,
    required String state,
  }) async {
    final data = await _api.post('/client/auth/oauth/$provider/callback', data: {
      'code': code,
      'state': state,
      'client': 'mobile',
    });
    return LoginResult.fromJson(asMap(data));
  }

  Future<Map<String, String>> i18n(String lang) async {
    final data = await _api.get('/client/config/i18n/$lang');
    return asMap(data)['messages'] is Map
        ? asMap(asMap(data)['messages']).map((key, value) => MapEntry(key, value.toString()))
        : const {};
  }
}
