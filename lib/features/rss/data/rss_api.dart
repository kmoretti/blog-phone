import '../../../data/api/api_client.dart';

class RssFeedDto {
  const RssFeedDto({
    required this.id,
    required this.friendLinkId,
    required this.name,
    required this.rssUrl,
    required this.times,
    required this.status,
    required this.isDied,
    required this.updatedAt,
  });
  final int id, friendLinkId, times, updatedAt;
  final String name, rssUrl, status;
  final bool isDied;
  factory RssFeedDto.fromJson(Map<String, dynamic> json) => RssFeedDto(
    id: _int(json['id']),
    friendLinkId: _int(json['friend_link_id']),
    name: _string(json['name']),
    rssUrl: _string(json['rss_url']),
    times: _int(json['times']),
    status: _string(json['status']),
    isDied: json['is_died'] == true || _int(json['is_died']) == 1,
    updatedAt: _int(json['updated_at']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'friend_link_id': friendLinkId,
    'name': name,
    'rss_url': rssUrl,
    'times': times,
    'status': status,
    'is_died': isDied,
    'updated_at': updatedAt,
  };
}

class RssPostDto {
  const RssPostDto({
    required this.id,
    required this.rssId,
    required this.title,
    required this.link,
    required this.description,
    required this.author,
    required this.time,
  });
  final int id, rssId, time;
  final String title, link, description, author;
  factory RssPostDto.fromJson(Map<String, dynamic> json) => RssPostDto(
    id: _int(json['id']),
    rssId: _int(json['rss_id']),
    title: _string(json['title']),
    link: _string(json['link']),
    description: _string(json['description']),
    author: _string(json['author']),
    time: _int(json['time']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'rss_id': rssId,
    'title': title,
    'link': link,
    'description': description,
    'author': author,
    'time': time,
  };
}

class RssPage<T> {
  const RssPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<T> items;
  final int total, page, pageSize;
}

class RssFetchResult {
  const RssFetchResult({
    required this.checkedItems,
    required this.insertedItems,
  });
  final int checkedItems, insertedItems;
  factory RssFetchResult.fromJson(Map<String, dynamic> json) => RssFetchResult(
    checkedItems: _int(json['checked_items']),
    insertedItems: _int(json['inserted_items']),
  );
}

class RssFeedPayload {
  const RssFeedPayload({required this.rssUrl, this.name, this.friendLinkId});
  final String rssUrl;
  final String? name;
  final int? friendLinkId;
  Map<String, dynamic> toJson() => {
    'rss_url': rssUrl,
    if (name != null) 'name': name,
    if (friendLinkId != null) 'friend_link_id': friendLinkId,
  };
}

class RssApi {
  const RssApi(this.client);
  final ApiClient client;
  Future<RssPage<RssFeedDto>> listFeeds({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final body = await client.get(
      'action/rss',
      queryParameters: {'page': page, 'page_size': pageSize, 'status': ?status},
    );
    return _feedPage(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<RssPage<RssPostDto>> listPosts({
    int? rssId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final body = await client.get(
      'public/rss/',
      queryParameters: {'page': page, 'page_size': pageSize, 'rss_id': ?rssId},
    );
    return _postPage(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<void> create(RssFeedPayload payload) =>
      client.post('action/rss', data: payload.toJson());
  Future<void> update(int id, RssFeedPayload payload) =>
      client.put('action/rss/$id', data: {'data': payload.toJson()});
  Future<void> delete(int id) => client.delete('action/rss/$id');
  Future<RssFetchResult> fetch(int id) async {
    final body = await client.post('action/rss/$id/fetch');
    return RssFetchResult.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  Future<void> refresh() => client.post('public/rss/refresh');
  Future<void> deletePost(int id) => client.delete('action/rss/posts/$id');
}

RssPage<RssFeedDto> _feedPage(Map<String, dynamic> json) => RssPage(
  items: _maps(json['items']).map(RssFeedDto.fromJson).toList(),
  total: _int(json['total']),
  page: _int(json['page']) == 0 ? 1 : _int(json['page']),
  pageSize: _int(json['page_size']) == 0 ? 20 : _int(json['page_size']),
);
RssPage<RssPostDto> _postPage(Map<String, dynamic> json) => RssPage(
  items: _maps(json['items']).map(RssPostDto.fromJson).toList(),
  total: _int(json['total']),
  page: _int(json['page']) == 0 ? 1 : _int(json['page']),
  pageSize: _int(json['page_size']) == 0 ? 20 : _int(json['page_size']),
);
int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String _string(Object? value) => value?.toString() ?? '';
List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];
