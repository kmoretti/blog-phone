import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/core/storage/secure_store.dart';
import 'package:blog_phone/data/api/api_client.dart';
import 'package:blog_phone/features/friends/data/friend_links_api.dart';

class FriendAdapter implements HttpClientAdapter {
  FriendAdapter(this.body, {this.statusCode = 200});

  final String body;
  final int statusCode;
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
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('loads public friend links from the public route with snapshot', () async {
    final adapter = FriendAdapter(
      '{"code":200,"data":{"items":[{"id":1,"name":"站点","link":"https://site.test","avatar":"https://site.test/a.png","description":"描述","snapshot":"https://site.test/snapshot.png","status":"survival","tags":["技术"]}],"total":1,"page":1,"page_size":20}}',
    );
    final api = FriendLinksApi(
      ApiClient(
        baseUrl: 'https://api.test',
        store: MemorySecureStore(),
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );

    final page = await api.list(admin: false);

    expect(
      adapter.request?.uri.toString(),
      'https://api.test/api/public/friend/?page=1&page_size=20',
    );
    expect(page.items.single.name, '站点');
    expect(page.items.single.tags, ['技术']);
    expect(page.items.single.snapshot, 'https://site.test/snapshot.png');
    expect(page.items.single.email, isNull);
  });

  test('submits an independent public friend application payload', () async {
    final adapter = FriendAdapter(
      '{"code":201,"data":{"id":9,"status":"pending"}}',
      statusCode: 201,
    );
    final api = FriendLinksApi(
      ApiClient(
        baseUrl: 'https://api.test',
        store: MemorySecureStore(),
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );

    await api.apply(
      const FriendLinkApplyPayload(
        name: '站点',
        link: 'https://site.test',
        avatar: 'https://site.test/a.png',
        description: '描述',
        email: 'owner@site.test',
        snapshot: 'https://site.test/snapshot.png',
        friendLinkPage: 'https://site.test/friends',
        feed: 'https://site.test/feed.xml',
        enableRss: true,
        turnstileToken: 'challenge-token',
      ),
    );

    expect(
      adapter.request?.uri.toString(),
      'https://api.test/api/public/friend/apply',
    );
    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.headers['X-Turnstile-Token'], 'challenge-token');
    expect(adapter.request?.data, const {
      'name': '站点',
      'link': 'https://site.test',
      'avatar': 'https://site.test/a.png',
      'description': '描述',
      'email': 'owner@site.test',
      'snapshot': 'https://site.test/snapshot.png',
      'friend_link_page': 'https://site.test/friends',
      'feed': 'https://site.test/feed.xml',
      'enable_rss': true,
    });
  });

  test('parses friend link groups and serializes group payloads', () {
    final group = FriendLinkGroup.fromJson({
      'id': 3,
      'name': '技术博客',
      'description': '技术类友链',
      'sort_order': 2,
      'created_at': 100,
      'updated_at': 200,
    });

    expect(group.id, 3);
    expect(group.name, '技术博客');
    expect(group.description, '技术类友链');
    expect(group.sortOrder, 2);
    expect(group.createdAt, 100);
    expect(group.updatedAt, 200);
    expect(
      const FriendLinkGroupPayload(
        name: '技术博客',
        description: '技术类友链',
        sortOrder: 2,
      ).toJson(),
      const {'name': '技术博客', 'description': '技术类友链', 'sort_order': 2},
    );
  });

  test('uses the existing friend group endpoints', () async {
    final adapter = FriendAdapter('{"code":200,"data":{"group_ids":[1,3]}}');
    final api = FriendLinksApi(
      ApiClient(
        baseUrl: 'https://api.test',
        store: MemorySecureStore({'jwt': 'token'}),
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );

    final groupIds = await api.getGroupIds(9);
    expect(groupIds, [1, 3]);
    expect(
      adapter.request?.uri.toString(),
      'https://api.test/api/action/friend/9/groups',
    );
    expect(adapter.request?.method, 'GET');

    final listAdapter = FriendAdapter(
      '{"code":200,"data":[{"id":3,"name":"技术博客","description":"","sort_order":0,"created_at":1,"updated_at":1}]}',
    );
    final listApi = FriendLinksApi(
      ApiClient(
        baseUrl: 'https://api.test',
        store: MemorySecureStore({'jwt': 'token'}),
        dio: Dio()..httpClientAdapter = listAdapter,
      ),
    );
    expect((await listApi.getGroups()).single.name, '技术博客');
    expect(
      listAdapter.request?.uri.toString(),
      'https://api.test/api/action/friend/group',
    );

    final createAdapter = FriendAdapter(
      '{"code":201,"data":{"id":3,"name":"技术博客","description":"技术类友链","sort_order":2,"created_at":100,"updated_at":200}}',
      statusCode: 201,
    );
    final createApi = FriendLinksApi(
      ApiClient(
        baseUrl: 'https://api.test',
        store: MemorySecureStore({'jwt': 'token'}),
        dio: Dio()..httpClientAdapter = createAdapter,
      ),
    );
    final created = await createApi.createGroup(
      const FriendLinkGroupPayload(
        name: '技术博客',
        description: '技术类友链',
        sortOrder: 2,
      ),
    );
    expect(created.id, 3);
    expect(createAdapter.request?.method, 'POST');
    expect(createAdapter.request?.data, const {
      'name': '技术博客',
      'description': '技术类友链',
      'sort_order': 2,
    });

    final mutationAdapter = FriendAdapter('{"code":200,"data":null}');
    final mutationApi = FriendLinksApi(
      ApiClient(
        baseUrl: 'https://api.test',
        store: MemorySecureStore({'jwt': 'token'}),
        dio: Dio()..httpClientAdapter = mutationAdapter,
      ),
    );
    await mutationApi.updateGroup(
      3,
      const FriendLinkGroupPayload(name: '新名称', sortOrder: 3),
    );
    expect(mutationAdapter.request?.method, 'PUT');
    expect(
      mutationAdapter.request?.uri.toString(),
      endsWith('/api/action/friend/group/3'),
    );
    await mutationApi.deleteGroup(3);
    expect(mutationAdapter.request?.method, 'DELETE');
    await mutationApi.setGroups(9, const []);
    expect(mutationAdapter.request?.method, 'PUT');
    expect(
      mutationAdapter.request?.uri.toString(),
      endsWith('/api/action/friend/9/groups'),
    );
    expect(mutationAdapter.request?.data, const {'group_ids': []});
  });

  test('migrates existing friend links through the backend endpoint', () async {
    final adapter = FriendAdapter(
      '{"code":200,"data":{"message":"migration completed"}}',
    );
    final api = FriendLinksApi(
      ApiClient(
        baseUrl: 'https://api.test',
        store: MemorySecureStore({'jwt': 'token'}),
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );

    await api.migrateGroups();

    expect(adapter.request?.method, 'POST');
    expect(
      adapter.request?.uri.toString(),
      'https://api.test/api/action/friend/group/migrate',
    );
    expect(adapter.request?.data, isNull);
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

  test('admin status filters include every backend status', () async {
    final source = await File(
      'lib/features/friends/presentation/friend_links_screen.dart',
    ).readAsString();
    final match = RegExp(
      r'class _AdminFilters[\s\S]*?children:\s*\[([^\]]+)\]',
    ).firstMatch(source);

    expect(match, isNotNull);
    final statuses = match!.group(1)!;
    expect(statuses, contains("'pending'"));
    expect(statuses, contains("'survival'"));
    expect(statuses, contains("'timeout'"));
    expect(statuses, contains("'error'"));
    expect(statuses, contains("'rejected'"));
  });

  test(
    'friend link editor includes snapshot and updated helper text',
    () async {
      final source = await File(
        'lib/features/friends/presentation/friend_links_screen.dart',
      ).readAsString();

      expect(source, contains("'snapshot': TextEditingController"));
      expect(source, contains("_field(fields['snapshot']!, '网站封面')"));
      expect(source, contains("snapshot: fields['snapshot']!.text.trim()"));
      expect(source, isNot(contains("_field(fields['rss']!, 'RSS 备用地址')")));
      expect(source, isNot(contains("'rss': TextEditingController")));
      expect(source, contains('开启后，系统不会自动检查该友链的可访问性。仅管理员使用。'));
    },
  );

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
    expect(
      adapter.request?.uri.toString(),
      'https://api.test/api/action/friend/7',
    );
    expect(adapter.request?.method, 'PUT');
    expect(adapter.request?.data, {
      'data': {'website_name': '新名'},
    });
  });

  test(
    'create posts the FriendWebsite fields directly without data wrapping',
    () async {
      final adapter = FriendAdapter('{"code":200,"data":{"id":7}}');
      final api = FriendLinksApi(
        ApiClient(
          baseUrl: 'https://api.test',
          store: MemorySecureStore({'jwt': 'token'}),
          dio: Dio()..httpClientAdapter = adapter,
        ),
      );

      await api.create(
        const FriendLinkPayload(
          name: '站点',
          link: 'https://site.test',
          avatar: 'https://site.test/a.png',
          description: '描述',
          email: 'owner@site.test',
          enableRss: true,
          skipHealthCheck: true,
          snapshot: 'https://site.test/snapshot.png',
          friendLinkPage: 'https://site.test/friends',
          feed: 'https://site.test/feed.xml',
          color: '#123456',
          rss: 'https://site.test/rss.xml',
          tags: ['技术'],
          status: 'pending',
          rejectionReason: '缺少描述',
        ),
      );

      expect(
        adapter.request?.uri.toString(),
        'https://api.test/api/action/friend',
      );
      expect(adapter.request?.method, 'POST');
      expect(adapter.request?.data, const {
        'name': '站点',
        'link': 'https://site.test',
        'avatar': 'https://site.test/a.png',
        'description': '描述',
        'email': 'owner@site.test',
        'enable_rss': true,
        'skip_health_check': true,
        'snapshot': 'https://site.test/snapshot.png',
        'friend_link_page': 'https://site.test/friends',
        'feed': 'https://site.test/feed.xml',
        'color': '#123456',
        'rss': 'https://site.test/rss.xml',
        'tags': ['技术'],
        'status': 'pending',
        'rejection_reason': '缺少描述',
      });
    },
  );

  test(
    'parses every friend link field and serializes the complete payload',
    () {
      final item = FriendLinkDto.fromJson({
        'id': 7,
        'name': '站点',
        'link': 'https://site.test',
        'avatar': 'https://site.test/a.png',
        'description': '描述',
        'email': 'owner@site.test',
        'enable_rss': true,
        'skip_health_check': true,
        'friend_link_page': 'https://site.test/friends',
        'feed': 'https://site.test/feed.xml',
        'color': '#123456',
        'rss': 'https://site.test/rss.xml',
        'tags': ['技术'],
        'status': 'pending',
        'rejection_reason': '缺少描述',
      });

      expect(item.email, 'owner@site.test');
      expect(item.enableRss, isTrue);
      expect(item.skipHealthCheck, isTrue);
      expect(item.friendLinkPage, 'https://site.test/friends');
      expect(item.feed, 'https://site.test/feed.xml');
      expect(item.color, '#123456');
      expect(item.rss, 'https://site.test/rss.xml');
      expect(item.rejectionReason, '缺少描述');

      const payload = FriendLinkPayload(
        name: '站点',
        link: 'https://site.test',
        avatar: 'https://site.test/a.png',
        description: '描述',
        email: 'owner@site.test',
        snapshot: 'https://site.test/snapshot.png',
        enableRss: true,
        skipHealthCheck: true,
        friendLinkPage: 'https://site.test/friends',
        feed: 'https://site.test/feed.xml',
        color: '#123456',
        rss: 'https://site.test/rss.xml',
        tags: ['技术'],
        status: 'approved',
        rejectionReason: '已处理',
      );
      expect(payload.toJson(), const {
        'data': {
          'website_name': '站点',
          'website_url': 'https://site.test',
          'website_icon_url': 'https://site.test/a.png',
          'description': '描述',
          'email': 'owner@site.test',
          'snapshot': 'https://site.test/snapshot.png',
          'enable_rss': true,
          'skip_health_check': true,
          'friend_link_page': 'https://site.test/friends',
          'feed': 'https://site.test/feed.xml',
          'color': '#123456',
          'rss': 'https://site.test/rss.xml',
          'tags': ['技术'],
          'status': 'approved',
          'rejection_reason': '已处理',
        },
      });
    },
  );
}
