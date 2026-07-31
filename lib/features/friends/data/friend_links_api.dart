import '../../../data/api/api_client.dart';

class FriendLinkDto {
  const FriendLinkDto({
    required this.id,
    required this.name,
    required this.link,
    required this.avatar,
    required this.description,
    required this.email,
    required this.enableRss,
    required this.skipHealthCheck,
    required this.friendLinkPage,
    required this.feed,
    required this.color,
    required this.rss,
    required this.tags,
    required this.status,
    required this.rejectionReason,
  });
  final int id;
  final String name, link, avatar, description, friendLinkPage, feed, color, rss, status, rejectionReason;
  final String? email;
  final bool enableRss, skipHealthCheck;
  final List<String> tags;
  factory FriendLinkDto.fromJson(Map<String, dynamic> json) => FriendLinkDto(
    id: _int(json['id']),
    name: _string(json['name'] ?? json['website_name']),
    link: _string(json['link'] ?? json['website_url']),
    avatar: _string(json['avatar'] ?? json['website_icon_url']),
    description: _string(json['description']),
    email: json['email']?.toString(),
    enableRss: _bool(json['enable_rss']),
    skipHealthCheck: _bool(json['skip_health_check']),
    friendLinkPage: _string(json['friend_link_page']),
    feed: _string(json['feed']),
    color: _string(json['color']),
    rss: _string(json['rss']),
    tags: _strings(json['tags']),
    status: _string(json['status']),
    rejectionReason: _string(json['rejection_reason']),
  );
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'link': link, 'avatar': avatar, 'description': description,
    'email': email, 'enable_rss': enableRss, 'skip_health_check': skipHealthCheck,
    'friend_link_page': friendLinkPage, 'feed': feed, 'color': color, 'rss': rss,
    'tags': tags, 'status': status, 'rejection_reason': rejectionReason,
  };
}

class FriendLinksPage {
  const FriendLinksPage({required this.items, required this.total, required this.page, required this.pageSize});
  final List<FriendLinkDto> items;
  final int total, page, pageSize;
  factory FriendLinksPage.fromJson(Map<String, dynamic> json) => FriendLinksPage(items: _maps(json['items'] ?? json['links']).map(FriendLinkDto.fromJson).toList(), total: _int(json['total']), page: _int(json['page']) == 0 ? 1 : _int(json['page']), pageSize: _int(json['page_size']) == 0 ? 20 : _int(json['page_size']));
}

class FriendLinkPayload {
  const FriendLinkPayload({
    this.name, this.link, this.avatar, this.description, this.email,
    this.enableRss, this.skipHealthCheck, this.friendLinkPage, this.feed,
    this.color, this.rss, this.tags, this.status, this.rejectionReason,
  });
  final String? name, link, avatar, description, email, friendLinkPage, feed, color, rss, status, rejectionReason;
  final bool? enableRss, skipHealthCheck;
  final List<String>? tags;
  Map<String, dynamic> toJson() => {'data': {
    if (name != null) 'website_name': name,
    if (link != null) 'website_url': link,
    if (avatar != null) 'website_icon_url': avatar,
    if (description != null) 'description': description,
    if (email != null) 'email': email,
    if (enableRss != null) 'enable_rss': enableRss,
    if (skipHealthCheck != null) 'skip_health_check': skipHealthCheck,
    if (friendLinkPage != null) 'friend_link_page': friendLinkPage,
    if (feed != null) 'feed': feed,
    if (color != null) 'color': color,
    if (rss != null) 'rss': rss,
    if (tags != null) 'tags': tags,
    if (status != null) 'status': status,
    if (rejectionReason != null) 'rejection_reason': rejectionReason,
  }};
}

class FriendLinksApi {
  const FriendLinksApi(this.client);
  final ApiClient client;

  Future<FriendLinksPage> list({bool admin = false, int page = 1, int pageSize = 20, String? status}) async {
    final query = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (status != null) query['status'] = status;
    final body = await client.get(admin ? 'action/friend' : 'friend/', queryParameters: query);
    return FriendLinksPage.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }
  Future<void> create(FriendLinkPayload payload) async => client.post('action/friend', data: payload.toJson()['data']);
  Future<void> update(int id, FriendLinkPayload payload) async => client.put('action/friend/$id', data: payload.toJson());
  Future<void> delete(int id) async => client.delete('action/friend/$id');
  Future<void> setGroups(int id, List<int> groupIds) async => client.put('action/friend/$id/groups', data: {'group_ids': groupIds});
  Future<void> createGroup(String name, String description) async => client.post('action/friend/group', data: {'name': name, 'description': description});
}

int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String _string(Object? value) => value?.toString() ?? '';
bool _bool(Object? value) => value == true || value == 1 || value == 'true' || value == '1';
List<Map<String, dynamic>> _maps(Object? value) => value is List ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : const [];
List<String> _strings(Object? value) => value is List ? value.map((item) => item.toString()).toList() : const [];
