import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api_client.dart';
import '../../../state/auth/auth_provider.dart';
import '../../../state/settings/settings_provider.dart';
import 'friend_links_api.dart';
import 'friend_links_repository.dart';

final friendLinksApiProvider = Provider<FriendLinksApi>((ref) {
  final auth = ref.watch(authProvider);
  ref.watch(networkRefreshProvider);
  final baseUrl = auth is AuthenticatedState
      ? auth.session.baseUrl
      : const String.fromEnvironment(
          'BLOG_API_BASE_URL',
          defaultValue: defaultApiBaseUrl,
        );
  return FriendLinksApi(
    ApiClient(baseUrl: baseUrl, store: ref.watch(secureStoreProvider)),
  );
});

final friendLinksRepositoryProvider = Provider<FriendLinksRepository>(
  (ref) => FriendLinksRepository(
    api: ref.watch(friendLinksApiProvider),
    database: ref.watch(appDatabaseProvider),
  ),
);
final friendLinksAdminProvider = Provider<bool>(
  (ref) => ref.watch(authProvider) is AuthenticatedState,
);
final friendLinksStatusProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

class FriendLinksQuery {
  const FriendLinksQuery({required this.admin, this.status});
  final bool admin;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is FriendLinksQuery &&
      other.admin == admin &&
      other.status == status;

  @override
  int get hashCode => Object.hash(admin, status);
}

final friendLinksPageProvider = FutureProvider.autoDispose
    .family<FriendLinksPage, FriendLinksQuery>(
      (ref, query) => ref
          .watch(friendLinksRepositoryProvider)
          .load(admin: query.admin, status: query.status),
    );
