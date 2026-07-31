import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api/api_client.dart';
import '../../../state/auth/auth_provider.dart';
import '../../../state/settings/settings_provider.dart';
import 'rss_api.dart';
import 'rss_repository.dart';

final rssApiProvider = Provider<RssApi>((ref) {
  final state = ref.watch(authProvider);
  ref.watch(networkRefreshProvider);
  final baseUrl = state is AuthenticatedState
      ? state.session.baseUrl
      : const String.fromEnvironment(
          'BLOG_API_BASE_URL',
          defaultValue: defaultApiBaseUrl,
        );
  return RssApi(
    ApiClient(baseUrl: baseUrl, store: ref.watch(secureStoreProvider)),
  );
});

final rssRepositoryProvider = Provider<RssRepository>(
  (ref) => RssRepository(
    api: ref.watch(rssApiProvider),
    database: ref.watch(appDatabaseProvider),
  ),
);

final rssFeedsProvider = FutureProvider.autoDispose.family<RssPage<RssFeedDto>, int>(
  (ref, page) => ref.watch(rssRepositoryProvider).feeds(page: page),
);

final rssPostsProvider = FutureProvider.autoDispose
    .family<RssPage<RssPostDto>, ({int? rssId, int page})>(
      (ref, query) => ref.watch(rssRepositoryProvider).posts(
        rssId: query.rssId,
        page: query.page,
      ),
    );
