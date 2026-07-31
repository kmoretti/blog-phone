import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/data/api/api_client.dart';
import 'package:blog_phone/data/db/app_database.dart';
import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/features/rss/data/rss_api.dart';
import 'package:blog_phone/features/rss/data/rss_provider.dart';
import 'package:blog_phone/features/rss/data/rss_repository.dart';
import 'package:blog_phone/features/rss/presentation/rss_screen.dart';

class _TestRssRepository extends RssRepository {
  _TestRssRepository() : super(api: RssApi(ApiClient(baseUrl: 'https://api.test', store: MemorySecureStore())), database: AppDatabase());

  @override
  Future<void> refresh() async {}
}

void main() {
  final feed = RssFeedDto(
    id: 1,
    friendLinkId: 1,
    name: 'Feed',
    rssUrl: 'https://feed.test',
    times: 0,
    status: 'valid',
    isDied: false,
    updatedAt: 1,
  );
  final post = RssPostDto(
    id: 2,
    rssId: 1,
    title: 'Post',
    link: 'https://post.test/article',
    description: 'Description',
    author: 'Author',
    time: DateTime(2026, 7, 31, 8).millisecondsSinceEpoch,
  );

  Widget buildSubject({required RssPage<RssFeedDto> feeds}) => ProviderScope(
    overrides: [
      rssRepositoryProvider.overrideWithValue(_TestRssRepository()),
      rssFeedsProvider(1).overrideWith((ref) async => feeds),
      rssPostsProvider((rssId: null, page: 1)).overrideWith((ref) async => RssPage(items: [post], total: 2, page: 1, pageSize: 1)),
      rssPostsProvider((rssId: 1, page: 1)).overrideWith((ref) async => RssPage(items: [post], total: 2, page: 1, pageSize: 1)),
    ],
    child: const MaterialApp(home: RssScreen()),
  );

  testWidgets('shows post local date and pagination controls', (tester) async {
    await tester.pumpWidget(buildSubject(feeds: RssPage(items: [feed], total: 2, page: 1, pageSize: 1)));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026/07/31'), findsOneWidget);
    expect(find.byTooltip('下一页'), findsNWidgets(2));
    expect(find.text('第 1 / 2 页'), findsNWidgets(2));
  });

  testWidgets('resets selected feed and all pages when refreshed', (tester) async {
    await tester.pumpWidget(buildSubject(feeds: RssPage(items: [feed], total: 2, page: 1, pageSize: 1)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(feed.name));
    await tester.pumpAndSettle();
    expect(find.text('指定 Feed 文章'), findsOneWidget);
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(find.text('全部文章'), findsOneWidget);
  });

  testWidgets('rejects a HTTP(S) URL without a host', (tester) async {
    final invalidPost = RssPostDto(
      id: post.id,
      rssId: post.rssId,
      title: post.title,
      link: 'https:///missing-host',
      description: post.description,
      author: post.author,
      time: post.time,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        rssFeedsProvider(1).overrideWith((ref) async => RssPage(items: [feed], total: 1, page: 1, pageSize: 20)),
        rssPostsProvider((rssId: null, page: 1)).overrideWith((ref) async => RssPage(items: [invalidPost], total: 1, page: 1, pageSize: 20)),
      ],
      child: const MaterialApp(home: RssScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(invalidPost.title));
    await tester.pump();
    expect(find.text('仅支持 HTTP(S) 链接'), findsOneWidget);
  });

  testWidgets('shows an error when launchUrl fails', (tester) async {
    final invalidPost = RssPostDto(
      id: post.id,
      rssId: post.rssId,
      title: post.title,
      link: 'javascript:alert(1)',
      description: post.description,
      author: post.author,
      time: post.time,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        rssFeedsProvider(1).overrideWith((ref) async => RssPage(items: [feed], total: 1, page: 1, pageSize: 20)),
        rssPostsProvider((rssId: null, page: 1)).overrideWith((ref) async => RssPage(items: [invalidPost], total: 1, page: 1, pageSize: 20)),
      ],
      child: const MaterialApp(home: RssScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(invalidPost.title));
    await tester.pump();

    expect(find.text('仅支持 HTTP(S) 链接'), findsOneWidget);
  });
}
