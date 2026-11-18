import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/platform/notification_service.dart';
import '../../../core/storage/local_store.dart';
import '../../../data/api/account_api.dart';
import '../../../data/api/auth_api.dart';
import '../../../data/models/user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required ApiClient api,
    required AuthApi authApi,
    required AccountApi accountApi,
    required LocalStore store,
  })  : _api = api,
        _authApi = authApi,
        _accountApi = accountApi,
        _store = store {
    _api.onUnauthorized = _handleUnauthorized;
    _api.onRefreshToken = refreshAccessToken;
    _restore();
  }

  static const _tokenKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _guestKey = 'auth_is_guest';
  static const _userKey = 'auth_user_cache';

  final ApiClient _api;
  final AuthApi _authApi;
  final AccountApi _accountApi;
  final LocalStore _store;

  String _accessToken = '';
  String _refreshToken = '';
  bool _isGuest = false;
  bool _initializing = true;
  bool _loading = false;
  String? _error;
  UserProfile? _user;
  String _pending2faTicket = '';
  int _sessionGeneration = 0;

  String get accessToken => _accessToken;
  String get refreshToken => _refreshToken;
  bool get isGuest => _isGuest;
  bool get isLoggedIn => _accessToken.isNotEmpty && !_isGuest;
  bool get isAuthenticated => _accessToken.isNotEmpty;
  bool get canAccessAccount => isLoggedIn;
  bool get initializing => _initializing;
  bool get loading => _loading;
  String? get error => _error;
  UserProfile? get user => _user;
  String get pending2faTicket => _pending2faTicket;

  String get displayName {
    if (_isGuest) return '游客';
    return _user?.displayName ?? 'KK用户';
  }

  void _restore() {
    _accessToken = _store.getString(_tokenKey) ?? '';
    _refreshToken = _store.getString(_refreshKey) ?? '';
    // 已移除游客登录：清理历史游客会话，统一要求账号登录。
    if (_store.getBool(_guestKey) ?? false) {
      _accessToken = '';
      _refreshToken = '';
      unawaited(_store.remove(_tokenKey));
      unawaited(_store.remove(_refreshKey));
      unawaited(_store.remove(_userKey));
      unawaited(_store.setBool(_guestKey, false));
    }
    _isGuest = false;
    final cached = _store.getMap(_userKey);
    if (cached.isNotEmpty) {
      _user = UserProfile.fromJson(cached);
    }
    _api.setToken(_accessToken.isEmpty ? null : _accessToken);
    _initializing = false;
    notifyListeners();
    if (isLoggedIn) {
      refreshProfile(silent: true);
    }
  }

  Future<void> refreshProfile({bool silent = false}) async {
    if (!isLoggedIn) return;
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      final generation = _sessionGeneration;
      final result = await _accountApi.profile();
      // 请求期间已退出登录/切换账号时，不能再把旧资料写回缓存。
      if (generation != _sessionGeneration || _accessToken.isEmpty) return;
      if (result.user != null) {
        _user = result.user!.copyWith(unreadMessages: result.unreadMessages);
        await _store.setMap(_userKey, _userToJson(_user!));
        notifyListeners();
      }
    } catch (_) {
      // 静默刷新失败不打断使用，网络恢复后重试。
    } finally {
      if (!silent) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<LoginResult?> loginPassword({
    required String account,
    required String password,
  }) async {
    return _doLogin(() => _authApi.login(
          method: 'password',
          account: account.trim(),
          password: password,
        ));
  }

  Future<LoginResult?> loginPhone({
    required String phone,
    required String code,
  }) async {
    return _doLogin(() => _authApi.login(
          method: 'phone',
          account: phone.trim(),
          code: code.trim(),
        ));
  }

  Future<LoginResult?> loginEmail({
    required String email,
    required String code,
  }) async {
    return _doLogin(() => _authApi.login(
          method: 'email',
          account: email.trim(),
          code: code.trim(),
        ));
  }

  Future<LoginResult?> register({
    required String method,
    required String phone,
    required String email,
    required String code,
    required String password,
    String? inviteCode,
    bool autoLogin = true,
  }) async {
    _setLoading(true);
    try {
      final result = await _authApi.register(
        method: method,
        phone: phone.trim(),
        email: email.trim(),
        code: code.trim(),
        password: password,
        inviteCode: inviteCode,
      );
      if (result.need2fa) {
        _pending2faTicket = result.ticket;
        _error = null;
        return result;
      }
      if (autoLogin) {
        await _applyLogin(result);
      } else {
        // 注册页需要回到登录页手动登录，不能在这里写入登录态，
        // 否则路由会立刻把注册页重定向到首页并吞掉成功提示。
        _error = null;
      }
      return result;
    } on ApiException catch (error) {
      _error = error.message;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loginAsGuest() async {
    _setLoading(true);
    try {
      final result = await _authApi.guest();
      _accessToken = result.accessToken;
      _isGuest = true;
      _user = null;
      _api.setToken(_accessToken);
      await _persist();
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<LoginResult?> _doLogin(Future<LoginResult> Function() action) async {
    _setLoading(true);
    try {
      final result = await action();
      if (result.need2fa) {
        _pending2faTicket = result.ticket;
        _error = null;
        return result;
      }
      await _applyLogin(result);
      return result;
    } on ApiException catch (error) {
      _error = error.message;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<LoginResult> verify2fa(String code) async {
    _setLoading(true);
    try {
      final result = await _authApi.verify2fa(ticket: _pending2faTicket, code: code.trim());
      await _applyLogin(result);
      _pending2faTicket = '';
      return result;
    } on ApiException catch (error) {
      _error = error.message;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<LoginResult> oauthLogin({
    required String provider,
    required String code,
    required String state,
  }) async {
    _setLoading(true);
    try {
      final result = await _authApi.oauthCallback(provider: provider, code: code, state: state);
      if (result.need2fa) {
        _pending2faTicket = result.ticket;
        _error = null;
        return result;
      }
      await _applyLogin(result);
      return result;
    } finally {
      _setLoading(false);
    }
  }

  bool get pending2fa => _pending2faTicket.isNotEmpty;

  Future<void> _applyLogin(LoginResult result) async {
    _pending2faTicket = '';
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _isGuest = result.guest;
    _user = result.user;
    _api.setToken(_accessToken);
    await _persist();
    notifyListeners();
    if (isLoggedIn) {
      unawaited(refreshProfile(silent: true));
    }
  }

  Future<void> _persist() async {
    await _store.setString(_tokenKey, _accessToken);
    await _store.setString(_refreshKey, _refreshToken);
    await _store.setBool(_guestKey, _isGuest);
    if (_user != null) {
      await _store.setMap(_userKey, _userToJson(_user!));
    } else {
      await _store.remove(_userKey);
    }
  }

  Future<void> updateUser(UserProfile user) async {
    _user = user;
    await _store.setMap(_userKey, _userToJson(user));
    notifyListeners();
  }

  /// access token 过期时用 refresh token 续期；失败返回 null，由调用方触发登出。
  Future<String?> refreshAccessToken() async {
    if (_refreshToken.isEmpty) return null;
    final generation = _sessionGeneration;
    final refreshing = _refreshToken;
    try {
      final result = await _authApi.refresh(refreshing);
      if (result.accessToken.isEmpty) return null;
      // 刷新期间用户已退出登录或换号，丢弃这次续期结果，避免"退出后又自动登录"。
      if (generation != _sessionGeneration || _refreshToken != refreshing) {
        return null;
      }
      _accessToken = result.accessToken;
      if (result.refreshToken.isNotEmpty) {
        _refreshToken = result.refreshToken;
      }
      _api.setToken(_accessToken);
      // 只更新令牌缓存，避免覆盖已缓存的用户资料。
      await _store.setString(_tokenKey, _accessToken);
      await _store.setString(_refreshKey, _refreshToken);
      notifyListeners();
      return _accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout({bool callApi = true}) async {
    _sessionGeneration++;
    if (callApi && _accessToken.isNotEmpty) {
      try {
        await _authApi.logout(refreshToken: _refreshToken);
      } catch (_) {
        // 忽略退出接口异常，本地会话必须清除。
      }
    }
    _accessToken = '';
    _refreshToken = '';
    _isGuest = false;
    _user = null;
    _pending2faTicket = '';
    _api.setToken(null);
    try {
      await _store.remove(_tokenKey);
      await _store.remove(_refreshKey);
      await _store.setBool(_guestKey, false);
      await _store.remove(_userKey);
      // 清理该账号的本地通知，避免切换账号后串消息。
      await NotificationService.instance.cancelAll();
    } catch (_) {
      // 本地清理失败也必须通知路由退出，否则会停留在已登录界面持续 401。
    } finally {
      notifyListeners();
    }
  }

  Future<void> _handleUnauthorized() async {
    if (_accessToken.isEmpty) return;
    await logout(callApi: false);
  }

  void _setLoading(bool value) {
    _loading = value;
    if (value) _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Map<String, dynamic> _userToJson(UserProfile profile) => {
        'id': profile.id,
        'username': profile.username,
        'nickname': profile.nickname,
        'avatar': profile.avatar,
        'signature': profile.signature,
        'phone': profile.phone,
        'email': profile.email,
        'status': profile.status,
        'totpEnabled': profile.totpEnabled,
        'unreadMessages': profile.unreadMessages,
        'createdAt': profile.createdAt?.toIso8601String(),
        'quotaConcurrent': profile.quotaConcurrent,
        'quotaMonthlyTrafficMb': profile.quotaMonthlyTrafficMb,
      };
}

void unawaited(Future<void> future) {
  // 明确忽略后台任务结果的辅助函数。
  future.catchError((Object _) {});
}
