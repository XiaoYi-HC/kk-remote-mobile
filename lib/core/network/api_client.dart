import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../utils/json_utils.dart';
import 'api_exception.dart';

typedef UnauthorizedHandler = Future<void> Function(String message);

/// 刷新 access token 的回调：成功返回新的 access token，失败返回 null。
typedef TokenRefreshHandler = Future<String?> Function();

/// 统一 REST 客户端：处理 BaseURL、鉴权头、统一响应结构与错误映射。
class ApiClient {
  ApiClient({String? baseUrl})
      : _baseUrl = baseUrl ?? AppConstants.defaultApiBaseUrl {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
          'X-Client-Platform': Platform.isIOS ? 'ios' : 'android',
          'X-Client-Version': AppConstants.appVersion,
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio _dio;
  String _baseUrl;
  String? _token;
  UnauthorizedHandler? onUnauthorized;
  TokenRefreshHandler? onRefreshToken;
  Future<bool>? _refreshInFlight;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  void updateBaseUrl(String? url) {
    if (url == null || url.trim().isEmpty) return;
    var normalized = url.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized == _baseUrl) return;
    _baseUrl = normalized;
    _dio.options.baseUrl = normalized;
  }

  /// 把服务端返回的相对地址转成可访问 URL。
  ///
  /// 以 `/` 开头的路径是站点根目录资源（如 `/uploads/avatars/x.png`），
  /// 必须拼到域名根上，而不是拼到 `/api/v1` 前缀上。
  Uri resolveUri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final base = Uri.parse(_baseUrl);
    if (path.startsWith('/')) {
      final origin = base.replace(path: '/', query: null, fragment: null);
      return origin.resolve(path);
    }
    final withSlash = base.path.endsWith('/')
        ? base
        : base.replace(path: '${base.path}/');
    return withSlash.resolve(path);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(String path, {Object? data, Map<String, dynamic>? query}) {
    return _send('POST', path, data: data, query: query);
  }

  Future<dynamic> put(String path, {Object? data, Map<String, dynamic>? query}) {
    return _send('PUT', path, data: data, query: query);
  }

  Future<dynamic> delete(String path, {Object? data, Map<String, dynamic>? query}) {
    return _send('DELETE', path, data: data, query: query);
  }

  /// 不触发自动刷新与登出的请求（用于刷新令牌等场景，避免递归）。
  Future<dynamic> postWithoutRetry(String path, {Object? data}) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: 'POST'),
      );
      return _unwrap(response);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) {
    // access token 过期（2h）时自动用 refresh token 续期并重试，避免直接退出登录。
    return _withAuthRetry(
      () async {
        final response = await _dio.request<dynamic>(
          path,
          data: data,
          queryParameters: query,
          options: Options(method: method),
        );
        return _unwrap(response);
      },
    );
  }

  Future<Map<String, dynamic>> uploadFile(
    String path,
    String filePath, {
    String field = 'file',
    Map<String, dynamic>? fields,
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _withAuthRetry(
      () async {
        final form = FormData();
        form.files.add(MapEntry(field, await MultipartFile.fromFile(filePath)));
        if (fields != null) {
          for (final entry in fields.entries) {
            form.fields.add(MapEntry(entry.key, entry.value.toString()));
          }
        }
        final response = await _dio.post<dynamic>(
          path,
          data: form,
          onSendProgress: onSendProgress,
        );
        return asMap(_unwrap(response));
      },
    );
  }

  /// 统一处理鉴权失效：先尝试刷新 token 并重试一次，失败才通知外部登出。
  Future<T> _withAuthRetry<T>(
    Future<T> Function() run, {
    bool retried = false,
  }) async {
    try {
      return await run();
    } on ApiException catch (error) {
      if (error.code != 1002) rethrow;
      if (!retried && await _tryRefreshToken()) {
        return _withAuthRetry(run, retried: true);
      }
      _notifyUnauthorized(error.message);
      rethrow;
    } on DioException catch (error) {
      if (_isUnauthorizedError(error)) {
        if (!retried && await _tryRefreshToken()) {
          return _withAuthRetry(run, retried: true);
        }
        _notifyUnauthorized(_mapDioError(error).message);
      }
      throw _mapDioError(error);
    }
  }

  bool _isUnauthorizedError(DioException error) {
    if (error.response?.statusCode == 401) return true;
    final body = error.response?.data;
    if (body is Map) {
      return asInt(asMap(body)['code'], fallback: 0) == 1002;
    }
    return false;
  }

  Future<bool> _tryRefreshToken() {
    final handler = onRefreshToken;
    if (handler == null) return Future<bool>.value(false);
    return _refreshInFlight ??= _doRefresh(handler);
  }

  Future<bool> _doRefresh(TokenRefreshHandler handler) async {
    try {
      final token = await handler();
      if (token == null || token.isEmpty) return false;
      _token = token;
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshInFlight = null;
    }
  }

  void _notifyUnauthorized(String message) {
    final handler = onUnauthorized;
    if (handler == null) return;
    unawaited(handler(message));
  }

  dynamic _unwrap(Response<dynamic> response) {
    final body = response.data;
    if (body is Map) {
      final map = asMap(body);
      final code = asInt(map['code'], fallback: 0);
      if (map.containsKey('code')) {
        if (code == 0) return map['data'];
        final message = asString(map['message'], fallback: '请求失败');
        throw ApiException(
          message,
          code: code,
          requestId: asStringOrNull(map['requestId']),
          statusCode: response.statusCode,
        );
      }
    }
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw ApiException(
        _statusMessage(response.statusCode!),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  ApiException _mapDioError(DioException error) {
    final response = error.response;
    if (response != null && response.data is Map) {
      final map = asMap(response.data);
      if (map.containsKey('code') || map.containsKey('message')) {
        final code = asInt(map['code'], fallback: -1);
        return ApiException(
          asString(map['message'], fallback: _statusMessage(response.statusCode ?? 500)),
          code: code,
          requestId: asStringOrNull(map['requestId']),
          statusCode: response.statusCode,
        );
      }
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('请求超时，请稍后重试', code: -3, statusCode: response?.statusCode);
      case DioExceptionType.connectionError:
        return NetworkUnavailableException();
      case DioExceptionType.cancel:
        return ApiException('请求已取消', code: -4);
      default:
        if (kDebugMode) {
          debugPrint('API error: ${error.message}');
        }
        // 无响应的底层错误（DNS、TLS、证书、连接被重置等）本质是网络不可用，
        // 不能统一当成服务端 500 误导用户。
        if (response == null) return NetworkUnavailableException();
        return ApiException(
          _statusMessage(response.statusCode ?? 500),
          statusCode: response.statusCode,
        );
    }
  }

  String _statusMessage(int status) {
    if (status == 401) return '登录状态已失效，请重新登录';
    if (status == 403) return '没有权限执行该操作';
    if (status == 404) return '请求的资源不存在';
    if (status == 429) return '操作过于频繁，请稍后再试';
    if (status >= 500) return '服务暂时不可用，请稍后重试';
    return '请求失败（$status）';
  }
}
