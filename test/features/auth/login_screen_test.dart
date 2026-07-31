import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/data/models/auth_models.dart';
import 'package:blog_phone/data/repositories/auth_repository.dart';
import 'package:blog_phone/features/auth/login_screen.dart';
import 'package:blog_phone/state/auth/auth_provider.dart';

class LoginRepository implements AuthRepository {
  LoginRepository(this.config);

  final VerifyConfig config;
  int configCalls = 0;
  int loginCalls = 0;
  String? token;

  @override
  Future<AuthSession?> restoreSession() async => null;

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
    loginCalls++;
    token = turnstileToken;
    return AuthSession(
      token: 'token',
      baseUrl: baseUrl,
      expiresAt: '2030-01-01 00:00:00',
    );
  }

  @override
  Future<VerifyConfig> getVerifyConfig(String baseUrl) async {
    configCalls++;
    return config;
  }

  @override
  Future<void> clearSession() async {}
}

class NullTurnstileProvider implements TurnstileTokenProvider {
  @override
  Future<String?> acquireToken({required String siteKey}) async => null;
}

void main() {
  testWidgets('loads verification config once on submit', (tester) async {
    final repository = LoginRepository(
      const VerifyConfig(
        turnstile: TurnstileConfig(enabled: false, siteKey: ''),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('server-url-field')),
      'https://example.com',
    );
    await tester.enterText(find.byKey(const Key('username-field')), 'admin');
    await tester.enterText(find.byKey(const Key('password-field')), 'secret');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(repository.configCalls, 1);
    expect(repository.loginCalls, 1);
  });

  testWidgets('blocks login when enabled Turnstile has no real token', (
    tester,
  ) async {
    final repository = LoginRepository(
      const VerifyConfig(
        turnstile: TurnstileConfig(enabled: true, siteKey: 'site-key'),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: LoginScreen(turnstileTokenProvider: NullTurnstileProvider()),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('server-url-field')),
      'https://example.com',
    );
    await tester.enterText(find.byKey(const Key('username-field')), 'admin');
    await tester.enterText(find.byKey(const Key('password-field')), 'secret');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turnstile-region')), findsOneWidget);
    expect(find.text('请完成安全验证'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });
}
