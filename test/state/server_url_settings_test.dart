import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/state/auth/auth_provider.dart';
import 'package:blog_phone/state/settings/settings_provider.dart';

void main() {
  test('server url is stored as next login default without replacing session url', () async {
    final settings = MemorySettingsStore({
      'server_url': 'https://active.example.com',
      'expires_at': '2030-01-01 00:00:00',
    });
    final secure = MemorySecureStore({'jwt': 'token'});
    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(secure),
        settingsStoreProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);

    final repository = container.read(authRepositoryProvider);
    final session = await repository.restoreSession();
    await repository.saveServerUrl('https://next.example.com');

    expect(session?.baseUrl, 'https://active.example.com');
    expect(await repository.readServerUrl(), 'https://next.example.com');
    expect(await settings.read('server_url'), 'https://active.example.com');
  });

  test('network coordinator notifies dependent providers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(networkRefreshProvider), 0);
    container.read(networkCoordinatorProvider).refresh();
    expect(container.read(networkRefreshProvider), 1);
  });
}
