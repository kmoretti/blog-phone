import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blog_phone/data/api/api_exception.dart';
import 'package:blog_phone/data/models/auth_models.dart';
import 'package:blog_phone/data/repositories/auth_repository.dart';
import 'package:blog_phone/state/auth/auth_provider.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.session});

  AuthSession? session;
  bool cleared = false;
  bool initialized = false;

  @override
  Future<AuthSession?> restoreSession() async {
    initialized = true;
    return session;
  }

  @override
  Future<String?> readServerUrl() async => null;

  @override
  Future<void> saveServerUrl(String baseUrl) async {}

  @override
  Future<AuthSession> login({
    required String baseUrl,
    required String username,
    required String password,
    String? turnstileToken,
  }) async {
    session = AuthSession(
      token: 'new-token',
      baseUrl: baseUrl,
      expiresAt: '2030-01-01 00:00:00',
    );
    return session!;
  }

  @override
  Future<VerifyConfig> getVerifyConfig(String baseUrl) async {
    return const VerifyConfig(
      turnstile: TurnstileConfig(enabled: false, siteKey: ''),
    );
  }

  @override
  Future<void> clearSession() async {
    cleared = true;
    session = null;
  }
}

void main() {
  test('restores authenticated state from stored session', () async {
    final repository = FakeAuthRepository(
      session: AuthSession(
        token: 'stored-token',
        baseUrl: 'https://example.com',
        expiresAt: '2030-01-01 00:00:00',
      ),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).restore();

    expect(container.read(authProvider), isA<AuthenticatedState>());
    expect(
      (container.read(authProvider) as AuthenticatedState).session.token,
      'stored-token',
    );
    expect(repository.initialized, isTrue);
  });

  test('missing stored session enters login state', () async {
    final repository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).restore();

    expect(container.read(authProvider), isA<LoginState>());
  });

  test('expired stored session enters guest state after clearing it', () async {
    final repository = ExpiredAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).restore();

    expect(container.read(authProvider), isA<GuestState>());
    expect(repository.cleared, isTrue);
  });

  test('login stores session and enters authenticated state', () async {
    final repository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(authProvider.notifier)
        .login(
          baseUrl: 'https://example.com',
          username: 'admin',
          password: 'secret',
        );

    expect(container.read(authProvider), isA<AuthenticatedState>());
    expect(
      (container.read(authProvider) as AuthenticatedState).session.token,
      'new-token',
    );
  });

  test('logout clears session and enters guest state', () async {
    final repository = FakeAuthRepository(
      session: AuthSession(
        token: 'stored-token',
        baseUrl: 'https://example.com',
        expiresAt: '2030-01-01 00:00:00',
      ),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).logout();

    expect(container.read(authProvider), isA<GuestState>());
    expect(repository.cleared, isTrue);
  });

  test('unauthorized error clears session and enters guest state', () async {
    final repository = FakeAuthRepository(
      session: AuthSession(
        token: 'stored-token',
        baseUrl: 'https://example.com',
        expiresAt: '2030-01-01 00:00:00',
      ),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).restore();
    await container
        .read(authProvider.notifier)
        .handleError(const ApiException(message: 'expired', statusCode: 401));

    expect(container.read(authProvider), isA<GuestState>());
    expect(repository.cleared, isTrue);
  });
}

class ExpiredAuthRepository extends FakeAuthRepository {
  @override
  Future<AuthSession?> restoreSession() async {
    await clearSession();
    throw const SessionExpiredException();
  }
}
