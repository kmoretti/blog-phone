import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/data/api/api_client.dart';
import 'package:blog_phone/data/api/api_exception.dart';
import 'package:blog_phone/data/api/auth_api.dart';
import 'package:blog_phone/data/models/auth_models.dart';

class ThrowingAdapter implements HttpClientAdapter {
  ThrowingAdapter(this.error);

  final DioException error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw error;
  }

  @override
  void close({bool force = false}) {}
}

class RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;
  ResponseBody response = ResponseBody.fromString(
    '{"code":200,"message":"登录成功","data":{"token":"token-value","expires_at":"2026-07-30 12:00:00"}}',
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return response;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('parses login token and expiration', () {
    final result = LoginResponse.fromJson({
      'code': 200,
      'message': '登录成功',
      'data': {'token': 'token-value', 'expires_at': '2026-07-30 12:00:00'},
    });
    expect(result.token, 'token-value');
    expect(result.expiresAt, '2026-07-30 12:00:00');
  });

  for (final baseUrl in [
    'https://example.com',
    'https://example.com/',
    'https://example.com/api',
    'https://example.com/api/',
  ]) {
    test('builds one api prefix for $baseUrl', () async {
      final adapter = RecordingAdapter();
      final client = ApiClient(
        baseUrl: baseUrl,
        store: MemorySecureStore({'jwt': 'existing-token'}),
        dio: Dio()..httpClientAdapter = adapter,
      );

      await AuthApi(client).login(username: 'admin', password: 'secret');

      expect(
        adapter.request?.uri.toString(),
        'https://example.com/api/verify/passwd',
      );
    });
  }

  test('sends auth header and turnstile token', () async {
    final adapter = RecordingAdapter();
    final client = ApiClient(
      baseUrl: 'https://example.com/api/',
      store: MemorySecureStore({'jwt': 'existing-token'}),
      dio: Dio()..httpClientAdapter = adapter,
    );

    await AuthApi(client).login(
      username: 'admin',
      password: 'secret',
      turnstileToken: 'challenge-token',
    );

    expect(adapter.request?.headers['Authorization'], 'Bearer existing-token');
    expect(adapter.request?.data, {
      'username': 'admin',
      'password': 'secret',
      'turnstile_token': 'challenge-token',
    });
  });

  test('parses public turnstile configuration', () async {
    final adapter = RecordingAdapter()
      ..response = ResponseBody.fromString(
        '{"code":200,"message":"success","data":{"turnstile":{"enable":true,"site_key":"site-key"}}}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    final api = AuthApi(
      ApiClient(
        baseUrl: 'https://example.com',
        store: MemorySecureStore(),
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );

    final config = await api.getVerifyConfig();

    expect(config.turnstile.enabled, isTrue);
    expect(config.turnstile.siteKey, 'site-key');
    expect(
      adapter.request?.uri.toString(),
      'https://example.com/api/public/verify_conf',
    );
  });

  test('maps network errors to a real ApiException', () async {
    final client = ApiClient(
      baseUrl: 'https://example.com',
      store: MemorySecureStore(),
      dio: Dio()
        ..httpClientAdapter = ThrowingAdapter(
          DioException(
            requestOptions: RequestOptions(path: 'public/verify_conf'),
            type: DioExceptionType.connectionError,
          ),
        ),
    );

    await expectLater(
      AuthApi(client).getVerifyConfig(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.isNetworkError,
          'isNetworkError',
          isTrue,
        ),
      ),
    );
  });

  test('maps timeout errors to a real ApiException', () async {
    final client = ApiClient(
      baseUrl: 'https://example.com',
      store: MemorySecureStore(),
      dio: Dio()
        ..httpClientAdapter = ThrowingAdapter(
          DioException(
            requestOptions: RequestOptions(path: 'public/verify_conf'),
            type: DioExceptionType.receiveTimeout,
          ),
        ),
    );

    await expectLater(
      AuthApi(client).getVerifyConfig(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.isTimeout,
          'isTimeout',
          isTrue,
        ),
      ),
    );
  });

  test('maps HTTP 401 and invokes unauthorized callback', () async {
    final adapter = RecordingAdapter()
      ..response = ResponseBody.fromString(
        '{"code":401,"message":"unauthorized"}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    var called = false;
    final client = ApiClient(
      baseUrl: 'https://example.com',
      store: MemorySecureStore(),
      onUnauthorized: () async => called = true,
      dio: Dio()..httpClientAdapter = adapter,
    );

    await expectLater(
      AuthApi(client).getVerifyConfig(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.isUnauthorized,
          'isUnauthorized',
          isTrue,
        ),
      ),
    );
    expect(called, isTrue);
  });
}
