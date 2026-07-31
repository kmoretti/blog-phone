import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blog_phone/state/settings/settings_provider.dart';

void main() {
  test('refreshes global data when connectivity returns at startup', () async {
    final connectivity = StreamController<List<ConnectivityResult>>();
    final container = ProviderContainer();
    addTearDown(() async {
      await connectivity.close();
      container.dispose();
    });

    final before = container.read(networkRefreshProvider);
    final subscription = NetworkRefreshStartup(
      stream: connectivity.stream,
      onOnline: container.read(networkCoordinatorProvider).refresh,
    ).start();
    addTearDown(subscription.cancel);

    connectivity.add(const [ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(networkRefreshProvider), before);

    connectivity.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(networkRefreshProvider), before + 1);
  });
}
