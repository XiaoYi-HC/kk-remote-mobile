import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../utils/json_utils.dart';
import 'api_exception.dart';

typedef UnauthorizedHandler = Future<void> Function();

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

  Uri resolveUri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final base = _baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/';
    return Uri.parse(base).resolve(path.startsWith('/') ? path.substring(1) : path);
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

  Future<dynamic> _send(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
      );
      return _unwrap(response);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> uploadFile(
    String path,
    String filePath, {
    String field = 'file',
    Map<String, dynamic>? fields,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
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
      final data = _unwrap(response);
      return asMap(data);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  dynamic _unwrap(Response<dynamic> response) {
    final body = response.data;
    if (body is Map) {
      final map = asMap(body);
      final code = asInt(map['code'], fallback: 0);
      if (map.containsKey('code')) {
        if (code == 0) return map['data'];
        final message = asString(map['message'], fallback: '请求失败');
        if (code == 1002) {
          onUnauthorized?.call();
        }
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
        if (code == 1002) {
          onUnauthorized?.call();
        }
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
        return ApiException(
          _statusMessage(response?.statusCode ?? 500),
          statusCode: response?.statusCode,
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
