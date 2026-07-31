import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/data/api/api_client.dart';
import 'package:blog_phone/features/rss/data/rss_api.dart';

class RssAdapter implements HttpClientAdapter {
  RssAdapter(this.body);
  final String body;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(body, 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('loads feeds and aggregated posts from public and admin endpoints', () async {
    final adapter = RssAdapter('{"code":200,"data":{"items":[{"id":1,"name":"Feed","rss_url":"https://feed.test","friend_link_id":-1,"times":0,"status":"valid","is_died":false,"updated_at":1}],"total":1,"page":1,"page_size":20}}');
    final api = RssApi(ApiClient(baseUrl: 'https://api.test', store: MemorySecureStore({'jwt': 'token'}), dio: Dio()..httpClientAdapter = adapter));
    final feeds = await api.listFeeds();
    expect(feeds.items.single.name, 'Feed');
    expect(adapter.request?.uri.toString(), 'https://api.test/api/action/rss?page=1&page_size=20');

    final postsAdapter = RssAdapter('{"code":200,"data":{"items":[{"id":2,"rss_id":1,"title":"Post","link":"https://post.test","description":"D","author":"A","time":3}],"total":1,"page":1,"page_size":20}}');
    final postsApi = RssApi(ApiClient(baseUrl: 'https://api.test', store: MemorySecureStore(), dio: Dio()..httpClientAdapter = postsAdapter));
    final posts = await postsApi.listPosts();
    expect(posts.items.single.title, 'Post');
    expect(postsAdapter.request?.uri.toString(), 'https://api.test/api/public/rss?page=1&page_size=20');
  });

  test('uses refresh, fetch, and delete endpoints', () async {
    final adapter = RssAdapter('{"code":200,"data":{"checked_items":2,"inserted_items":1}}');
    final api = RssApi(ApiClient(baseUrl: 'https://api.test', store: MemorySecureStore({'jwt': 'token'}), dio: Dio()..httpClientAdapter = adapter));
    await api.fetch(4);
    expect(adapter.request?.uri.path, '/api/action/rss/4/fetch');
    await api.listFeeds(page: 2, pageSize: 10);
    expect(adapter.request?.uri.queryParameters['page'], '2');
    expect(adapter.request?.uri.queryParameters['page_size'], '10');
    await api.listPosts(rssId: 7, page: 2, pageSize: 10);
    expect(adapter.request?.uri.queryParameters['rss_id'], '7');
    expect(adapter.request?.uri.queryParameters['page'], '2');
    await api.deletePost(9);
    expect(adapter.request?.uri.path, '/api/action/rss/posts/9');
  });
}
