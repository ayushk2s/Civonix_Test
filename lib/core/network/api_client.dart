import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/failures.dart';

const _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://192.168.1.3:8000');
const _accessKey = 'access_token';
const _refreshKey = 'refresh_token';

class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  static ApiClient? _instance;
  factory ApiClient() => _instance ??= ApiClient._();

  ApiClient._()
      : _storage = const FlutterSecureStorage(),
        _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        )) {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: false,
      responseHeader: false,
      error: true,
      logPrint: (o) => debugPrint('[API] $o'),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _accessKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        debugPrint('[API ERROR] ${error.requestOptions.path} → '
            '${error.response?.statusCode} ${error.response?.data}');
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            final token = await _storage.read(key: _accessKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final retry = await _dio.fetch(error.requestOptions);
            handler.resolve(retry);
            return;
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refresh = await _storage.read(key: _refreshKey);
      if (refresh == null) return false;
      final resp = await _dio.post('/api/v1/auth/refresh', data: {'refresh_token': refresh});
      await saveTokens(resp.data['access_token'], resp.data['refresh_token']);
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  Future<bool> hasToken() async => await _storage.read(key: _accessKey) != null;

  // ── HTTP Methods ──────────────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final resp = await _dio.get(path, queryParameters: queryParams);
      return resp.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? queryParams}) async {
    try {
      final resp = await _dio.post(path, data: data, queryParameters: queryParams);
      return resp.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      final resp = await _dio.patch(path, data: data);
      return resp.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Failure _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    final rawData = e.response?.data;
    final rawDetail = rawData is Map ? rawData['detail'] : rawData;
    final detail = rawDetail is List
        ? rawDetail.map((d) => d['msg'] ?? d.toString()).join(', ')
        : rawDetail?.toString() ?? e.message ?? 'Unknown error';

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkFailure('Connection timed out');
    }
    if (e.type == DioExceptionType.unknown) {
      return NetworkFailure('Network error: $detail');
    }

    switch (statusCode) {
      case 401: return AuthFailure(detail.toString());
      case 403: return AuthFailure('Access denied');
      case 404: return NotFoundFailure(detail.toString());
      case 409: return ValidationFailure(detail.toString());
      case 422: return ValidationFailure(detail.toString());
      case 502: return ExchangeFailure(detail.toString());
      default:  return ServerFailure(detail.toString(), statusCode: statusCode);
    }
  }
}
