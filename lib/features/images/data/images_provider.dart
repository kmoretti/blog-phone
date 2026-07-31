import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api/api_client.dart';
import '../../../state/auth/auth_provider.dart';
import '../../../state/settings/settings_provider.dart';
import 'images_api.dart';
import 'images_repository.dart';

final imagesApiProvider = Provider<ImagesApi>((ref) {
  final state = ref.watch(authProvider);
  ref.watch(networkRefreshProvider);
  final baseUrl = state is AuthenticatedState ? state.session.baseUrl : const String.fromEnvironment('BLOG_API_BASE_URL', defaultValue: 'http://localhost');
  return ImagesApi(ApiClient(baseUrl: baseUrl, store: ref.watch(secureStoreProvider)));
});
final imagesRepositoryProvider = Provider<ImagesRepository>((ref) => ImagesRepository(api: ref.watch(imagesApiProvider), database: ref.watch(appDatabaseProvider)));
final imagesPageProvider = FutureProvider.autoDispose<ImagePage>((ref) => ref.watch(imagesRepositoryProvider).list());
