import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';

final serverUrlProvider = FutureProvider<String?>((ref) {
  return ref.watch(authProvider.notifier).readServerUrl();
});

final networkRefreshProvider = StateProvider<int>((ref) => 0);

class NetworkCoordinator {
  NetworkCoordinator(this.ref);

  final Ref ref;

  void refresh() {
    ref.read(networkRefreshProvider.notifier).state++;
  }
}

final networkCoordinatorProvider = Provider<NetworkCoordinator>(
  (ref) => NetworkCoordinator(ref),
);

class NetworkRefreshStartup {
  NetworkRefreshStartup({required this.stream, required this.onOnline});

  final Stream<List<ConnectivityResult>> stream;
  final void Function() onOnline;

  StreamSubscription<List<ConnectivityResult>> start() {
    var wasOffline = false;
    return stream.listen((results) {
      final isOffline = results.every((result) => result == ConnectivityResult.none);
      if (isOffline) {
        wasOffline = true;
      } else if (wasOffline) {
        wasOffline = false;
        onOnline();
      }
    });
  }
}
