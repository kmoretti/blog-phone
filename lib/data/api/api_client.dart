import 'package:dio/dio.dart';

import '../../core/storage/secure_store.dart';
import 'api_exception.dart';

const defaultApiBaseUrl = 'https://blog-api.2005815.xyz';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.store,
    Dio? dio,
    this.timeout = const Duration(seconds: 15),
    this.onUnauthorized,
  }) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: '${_normalizeBaseUrl(baseUrl)}/',
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      responseType: ResponseType.json,
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await store.read('jwt');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final fingerprintToken = await store.read('fingerprint_token');
          if (fingerprintToken != null && fingerprintToken.isNotEmpty) {
            options.headers['X-Fingerprint-Token'] = fingerprintToken;
          }
          final antibotToken = await store.read('antibot_token');
          if (antibotToken != null && antibotToken.isNotEmpty) {
            options.headers['X-Antibot-Token'] = antibotToken;
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureStore store;
  final Duration timeout;
  final Future<void> Function()? onUnauthorized;

  Future<bool> hasFingerprintToken() async {
    final token = await store.read('fingerprint_token');
    return token != null && token.isNotEmpty;
  }

  Future<void> ensureFingerprintToken() async {
    if (await hasFingerprintToken() &&
        (await store.read('antibot_token'))?.isNotEmpty == true) {
      return;
    }
    final verifyResponse = await _request(() => _dio.post('verify/turnstile'));
    final verifyBody = Map<String, dynamic>.from(verifyResponse as Map);
    final antibotToken = (verifyBody['data'] as Map?)?['antibot_token']
        ?.toString();
    if (antibotToken == null || antibotToken.isEmpty) {
      throw const ApiException(message: '无法获取访客验证 token', statusCode: 401);
    }
    final fingerprintResponse = await _request(
      () => _dio.post(
        'verify/fingerprint',
        options: Options(headers: {'X-Antibot-Token': antibotToken}),
      ),
    );
    final fingerprintBody = Map<String, dynamic>.from(
      fingerprintResponse as Map,
    );
    final fingerprintToken =
        (fingerprintBody['data'] as Map?)?['fingerprint_token']?.toString();
    if (fingerprintToken == null || fingerprintToken.isEmpty) {
      throw const ApiException(
        message: '无法获取 fingerprint token',
        statusCode: 401,
      );
    }
    await store.write('antibot_token', antibotToken);
    await store.write('fingerprint_token', fingerprintToken);
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request(() => _dio.get(path, queryParameters: queryParameters));
  }

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request(
      () => _dio.post(path, data: data, queryParameters: queryParameters),
    );
  }

  Future<dynamic> put(String path, {Object? data}) async {
    return _request(() => _dio.put(path, data: data));
  }

  Future<dynamic> delete(String path, {Object? data}) async {
    return _request(() => _dio.delete(path, data: data));
  }

  Future<dynamic> _request(Future<Response<dynamic>> Function() request) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await request();
        final body = response.data;
        if (response.statusCode == null ||
            response.statusCode! < 200 ||
            response.statusCode! >= 300) {
          final exception = _exceptionFromResponse(response);
          await _notifyUnauthorized(exception);
          if (!exception.isRetryable || attempt == 2) throw exception;
          continue;
        }
        if (body is Map<String, dynamic> &&
            body['code'] is num &&
            body['code'] != 200) {
          final exception = _exceptionFromBody(body, response.statusCode);
          await _notifyUnauthorized(exception);
          if (!exception.isRetryable || attempt == 2) throw exception;
          continue;
        }
        return body;
      } on ApiException catch (error) {
        if (!error.isRetryable || attempt == 2) rethrow;
      } on DioException catch (error) {
        final exception = _exceptionFromDio(error);
        await _notifyUnauthorized(exception);
        if (!exception.isRetryable || attempt == 2) throw exception;
      } catch (error) {
        throw ApiException(message: error.toString());
      }
    }
    throw const ApiException(message: '请求失败');
  }

  Future<void> _notifyUnauthorized(ApiException exception) async {
    if (exception.isUnauthorized) {
      await onUnauthorized?.call();
    }
  }

  ApiException _exceptionFromDio(DioException error) {
    if (error.error is ApiException) return error.error as ApiException;
    if (error.response != null) return _exceptionFromResponse(error.response!);
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ApiException(message: '请求超时，请稍后重试', isTimeout: true);
    }
    return ApiException(
      message: '网络请求失败，请检查网络连接',
      statusCode: error.response?.statusCode,
      isNetworkError: true,
    );
  }

  ApiException _exceptionFromResponse(Response<dynamic> response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      return _exceptionFromBody(body, response.statusCode);
    }
    return ApiException(
      message: '请求失败（${response.statusCode ?? '未知'}）',
      statusCode: response.statusCode,
    );
  }

  ApiException _exceptionFromBody(Map<String, dynamic> body, int? statusCode) {
    final code = (body['code'] as num?)?.toInt();
    final message = body['message']?.toString();
    return ApiException(
      message: message == null || message.isEmpty ? '请求失败' : message,
      statusCode: statusCode,
      code: code,
    );
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim().replaceFirst(RegExp(r'/+$'), '');
    return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
  }
}
