import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blog_phone/app.dart';
import 'package:blog_phone/data/models/auth_models.dart';
import 'package:blog_phone/data/repositories/auth_repository.dart';
import 'package:blog_phone/state/auth/auth_provider.dart';

class AppRepository implements AuthRepository {
  AppRepository(this.session);

  final AuthSession? session;

  @override
  Future<AuthSession?> restoreSession() async => session;

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
  }) => throw UnimplementedError();

  @override
  Future<VerifyConfig> getVerifyConfig(String baseUrl) =>
      throw UnimplementedError();

  @override
  Future<void> clearSession() async {}
}

void main() {
  testWidgets('routes login state to login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(AppRepository(null)),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsWidgets);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
  });

  testWidgets('routes guest state to home shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(AppRepository(null)),
          authProvider.overrideWith(() => GuestAuthNotifier()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
  });
}

class GuestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const GuestState();
}
