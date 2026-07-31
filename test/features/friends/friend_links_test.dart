import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/data/api/api_client.dart';
import 'package:blog_phone/features/friends/data/friend_links_api.dart';

class FriendAdapter implements HttpClientAdapter {
  FriendAdapter(this.body);

  final String body;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('loads public friend links without exposing admin fields', () async {
    final adapter = FriendAdapter(
      '{"code":200,"data":{"items":[{"id":1,"name":"站点","link":"https://site.test","avatar":"https://site.test/a.png","description":"描述","status":"survival","tags":["技术"]}],"total":1,"page":1,"page_size":20}}',
    );
    final api = FriendLinksApi(
      ApiClient(
        baseUrl: 'https://api.test',
        store: MemorySecureStore(),
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );

    final page = await api.list(admin: false);

    expect(adapter.request?.uri.toString(), 'https://api.test/api/friend/?page=1&page_size=20');
    expect(page.items.single.name, '站点');
    expect(page.items.single.tags, ['技术']);
    expect(page.items.single.email, isNull);
  });

  test('passes the selected status to the friend list API', () async {
    final adapter = FriendAdapter(
      '{"code":200,"data":{"items":[],"total":0,"page":1,"page_size":20}}',
    );
    final api = FriendLinksApi(
      ApiClient(
        baseUrl: 'https://api.test',
        store: MemorySecureStore({'jwt': 'token'}),
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );

    await api.list(admin: true, status: 'pending');

    expect(
      adapter.request?.uri.toString(),
      'https://api.test/api/action/friend?page=1&page_size=20&status=pending',
    );
  });

  test('admin mutations use authenticated friend action endpoints', () async {
    final adapter = FriendAdapter('{"code":200,"data":{}}');
    final api = FriendLinksApi(
      ApiClient(
        baseUrl: 'https://api.test',
        store: MemorySecureStore({'jwt': 'token'}),
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );

    await api.update(7, const FriendLinkPayload(name: '新名'));
    expect(adapter.request?.uri.toString(), 'https://api.test/api/action/friend/7');
    expect(adapter.request?.method, 'PUT');
    expect(adapter.request?.data, {'data': {'website_name': '新名'}});
  });
}
