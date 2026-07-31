import '../../../data/api/api_client.dart';

class FriendLinkDto {
  const FriendLinkDto({required this.id, required this.name, required this.link, required this.avatar, required this.description, required this.status, required this.tags, this.email});
  final int id;
  final String name, link, avatar, description, status;
  final List<String> tags;
  final String? email;
  factory FriendLinkDto.fromJson(Map<String, dynamic> json) => FriendLinkDto(
    id: _int(json['id']), name: _string(json['name']), link: _string(json['link']), avatar: _string(json['avatar']), description: _string(json['description']), status: _string(json['status']), tags: _strings(json['tags']), email: json['email']?.toString(),
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'link': link, 'avatar': avatar, 'description': description, 'status': status, 'tags': tags, if (email != null) 'email': email};
}

class FriendLinksPage {
  const FriendLinksPage({required this.items, required this.total, required this.page, required this.pageSize});
  final List<FriendLinkDto> items;
  final int total, page, pageSize;
  factory FriendLinksPage.fromJson(Map<String, dynamic> json) => FriendLinksPage(items: _maps(json['items'] ?? json['links']).map(FriendLinkDto.fromJson).toList(), total: _int(json['total']), page: _int(json['page']) == 0 ? 1 : _int(json['page']), pageSize: _int(json['page_size']) == 0 ? 20 : _int(json['page_size']));
}

class FriendLinkPayload {
  const FriendLinkPayload({this.name, this.link, this.avatar, this.description, this.status, this.email, this.tags});
  final String? name, link, avatar, description, status, email;
  final List<String>? tags;
  Map<String, dynamic> toJson() => {'data': {if (name != null) 'website_name': name, if (link != null) 'website_url': link, if (avatar != null) 'website_icon_url': avatar, if (description != null) 'description': description, if (status != null) 'status': status, if (email != null) 'email': email, if (tags != null) 'tags': tags}};
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
List<Map<String, dynamic>> _maps(Object? value) => value is List ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : const [];
List<String> _strings(Object? value) => value is List ? value.map((item) => item.toString()).toList() : const [];
