import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/data/repositories/auth_repository.dart';
import 'package:blog_phone/state/auth/auth_provider.dart';

void main() {
  test('auth repository uses replaceable secure and settings stores', () {
    final secureStore = MemorySecureStore({'jwt': 'token'});
    final settingsStore = MemorySettingsStore({
      'server_url': 'https://example.com',
    });
    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(secureStore),
        settingsStoreProvider.overrideWithValue(settingsStore),
      ],
    );
    addTearDown(container.dispose);

    final repository = container.read(authRepositoryProvider);

    expect(repository, isA<DefaultAuthRepository>());
    final defaultRepository = repository as DefaultAuthRepository;
    expect(defaultRepository.secureStore, same(secureStore));
    expect(defaultRepository.settingsStore, same(settingsStore));
  });

  test('memory settings store reads, writes, and deletes values', () async {
    final store = MemorySettingsStore({'theme': 'light'});

    expect(await store.read('theme'), 'light');

    await store.write('theme', 'dark');
    expect(await store.read('theme'), 'dark');

    await store.delete('theme');
    expect(await store.read('theme'), isNull);
  });
}
