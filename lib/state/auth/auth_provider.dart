import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/database_settings_store.dart';
import '../../core/storage/secure_store.dart';
import '../../data/db/app_database.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';

final secureStoreProvider = Provider<SecureStore>(
  (ref) => FlutterSecureStore(),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => DatabaseSettingsStore(ref.watch(appDatabaseProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return DefaultAuthRepository(
    secureStore: ref.watch(secureStoreProvider),
    settingsStore: ref.watch(settingsStoreProvider),
    onUnauthorized: () => ref.read(authProvider.notifier).logout(),
  );
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

sealed class AuthState {
  const AuthState();
}

class UnknownState extends AuthState {
  const UnknownState();
}

class LoginState extends AuthState {
  const LoginState();
}

class GuestState extends AuthState {
  const GuestState();
}

class LoadingState extends AuthState {
  const LoadingState();
}

class AuthenticatedState extends AuthState {
  const AuthenticatedState(this.session);

  final AuthSession session;
}

class ErrorState extends AuthState {
  const ErrorState(this.message);

  final String message;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const UnknownState();

  Future<void> restore() async {
    state = const LoadingState();
    try {
      final session = await ref.read(authRepositoryProvider).restoreSession();
      state = session == null
          ? const LoginState()
          : AuthenticatedState(session);
    } on SessionExpiredException {
      state = const GuestState();
    } catch (error) {
      state = ErrorState(error.toString());
    }
  }

  Future<String?> readServerUrl() {
    return ref.read(authRepositoryProvider).readServerUrl();
  }

  Future<void> saveServerUrl(String baseUrl) {
    return ref.read(authRepositoryProvider).saveServerUrl(baseUrl);
  }

  Future<void> login({
    required String baseUrl,
    required String username,
    required String password,
    String? turnstileToken,
  }) async {
    state = const LoadingState();
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(
            baseUrl: baseUrl,
            username: username,
            password: password,
            turnstileToken: turnstileToken,
          );
      state = AuthenticatedState(session);
    } on ApiException catch (error) {
      await handleError(error);
    } catch (error) {
      state = ErrorState(error.toString());
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).clearSession();
    state = const GuestState();
  }

  void continueAsGuest() {
    state = const GuestState();
  }

  Future<void> handleError(ApiException error) async {
    if (error.isUnauthorized) {
      await ref.read(authRepositoryProvider).clearSession();
      state = const GuestState();
      return;
    }
    state = ErrorState(error.message);
  }
}
