import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api_client.dart';
import '../../../state/auth/auth_provider.dart';
import '../../../state/settings/settings_provider.dart';
import 'moments_api.dart';
import 'moments_repository.dart';

final momentsApiProvider = Provider<MomentsApi>((ref) {
  final session = ref.watch(authProvider);
  ref.watch(networkRefreshProvider);
  final store = ref.watch(secureStoreProvider);
  final baseUrl = session is AuthenticatedState
      ? session.session.baseUrl
      : const String.fromEnvironment(
          'BLOG_API_BASE_URL',
          defaultValue: defaultApiBaseUrl,
        );
  return MomentsApi(
    client: ApiClient(baseUrl: baseUrl, store: store),
  );
});

final momentsAdminProvider = Provider<bool>(
  (ref) => ref.watch(authProvider) is AuthenticatedState,
);

final momentsRepositoryProvider = Provider<MomentsRepository>(
  (ref) => MomentsRepository(
    api: ref.watch(momentsApiProvider),
    database: ref.watch(appDatabaseProvider),
  ),
);

final momentsPageProvider = FutureProvider.autoDispose
    .family<MomentsPage, bool>(
      (ref, admin) async =>
          ref.watch(momentsRepositoryProvider).load(admin: admin),
    );
