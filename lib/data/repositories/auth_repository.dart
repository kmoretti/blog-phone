import '../../core/storage/secure_store.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../models/auth_models.dart';

abstract interface class AuthRepository {
  Future<AuthSession?> restoreSession();
  Future<String?> readServerUrl();
  Future<void> saveServerUrl(String baseUrl);
  Future<AuthSession> login({
    required String baseUrl,
    required String username,
    required String password,
    String? turnstileToken,
  });
  Future<VerifyConfig> getVerifyConfig(String baseUrl);
  Future<void> clearSession();
}

class DefaultAuthRepository implements AuthRepository {
  DefaultAuthRepository({
    required this.secureStore,
    required this.settingsStore,
    AuthApiFactory? apiFactory,
    this.onUnauthorized,
  }) : _apiFactory =
           apiFactory ??
           ((baseUrl, store) => AuthApi(
             ApiClient(
               baseUrl: baseUrl,
               store: store,
               onUnauthorized: onUnauthorized,
             ),
           ));

  final SecureStore secureStore;
  final SettingsStore settingsStore;
  final AuthApiFactory _apiFactory;
  final Future<void> Function()? onUnauthorized;

  @override
  Future<String?> readServerUrl() => settingsStore.read('server_url_default');

  @override
  Future<void> saveServerUrl(String baseUrl) =>
      settingsStore.write('server_url_default', baseUrl.trim());

  @override
  Future<AuthSession?> restoreSession() async {
    final token = await secureStore.read('jwt');
    final baseUrl = await settingsStore.read('server_url');
    final expiresAt = await settingsStore.read('expires_at');
    if (token == null || token.isEmpty || baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    if (expiresAt == null || expiresAt.isEmpty) {
      await clearSession();
      throw const SessionExpiredException();
    }
    final expiry = _parseExpiry(expiresAt);
    if (expiry == null || !expiry.isAfter(DateTime.now())) {
      await clearSession();
      throw const SessionExpiredException();
    }
    return AuthSession(token: token, baseUrl: baseUrl, expiresAt: expiresAt);
  }

  @override
  Future<AuthSession> login({
    required String baseUrl,
    required String username,
    required String password,
    String? turnstileToken,
  }) async {
    final result = await _apiFactory(baseUrl, secureStore).login(
      username: username,
      password: password,
      turnstileToken: turnstileToken,
    );
    if (result.token.isEmpty || _parseExpiry(result.expiresAt) == null) {
      throw const ApiException(message: '登录响应无效');
    }
    final expiry = _parseExpiry(result.expiresAt);
    if (!expiry!.isAfter(DateTime.now())) {
      throw const ApiException(message: '登录状态已过期');
    }
    await secureStore.write('jwt', result.token);
    await saveServerUrl(baseUrl);
    await settingsStore.write('server_url', baseUrl);
    await settingsStore.write('expires_at', result.expiresAt);
    return AuthSession(
      token: result.token,
      baseUrl: baseUrl,
      expiresAt: result.expiresAt,
    );
  }

  @override
  Future<VerifyConfig> getVerifyConfig(String baseUrl) {
    return _apiFactory(baseUrl, secureStore).getVerifyConfig();
  }

  DateTime? _parseExpiry(String value) {
    return DateTime.tryParse(value) ??
        DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  @override
  Future<void> clearSession() async {
    await Future.wait([
      secureStore.delete('jwt'),
      settingsStore.delete('server_url'),
      settingsStore.delete('expires_at'),
    ]);
  }
}

typedef AuthApiFactory = AuthApi Function(String baseUrl, SecureStore store);
