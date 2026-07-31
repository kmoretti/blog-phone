import '../../../data/api/api_client.dart';
import '../../../data/api/api_exception.dart';

class MomentMediaDto {
  const MomentMediaDto({
    required this.id,
    required this.momentId,
    required this.name,
    required this.mediaUrl,
    required this.mediaType,
    required this.isLocal,
    required this.isDeleted,
  });
  final int id;
  final int momentId;
  final String name;
  final String mediaUrl;
  final String mediaType;
  final int isLocal;
  final int isDeleted;
  factory MomentMediaDto.fromJson(Map<String, dynamic> json) => MomentMediaDto(
    id: _int(json['id']),
    momentId: _int(json['moment_id']),
    name: _string(json['name']),
    mediaUrl: _string(json['media_url']),
    mediaType: _string(json['media_type']),
    isLocal: _int(json['is_local']),
    isDeleted: _int(json['is_deleted']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'moment_id': momentId,
    'name': name,
    'media_url': mediaUrl,
    'media_type': mediaType,
    'is_local': isLocal,
    'is_deleted': isDeleted,
  };
}

class MomentDto {
  const MomentDto({
    required this.id,
    required this.content,
    required this.tags,
    required this.pinnedOrder,
    required this.isAd,
    required this.extension,
    required this.status,
    required this.messageLink,
    required this.createdAt,
    required this.updatedAt,
    required this.media,
    required this.reactions,
    required this.selectedReaction,
  });
  final int id;
  final String content;
  final String tags;
  final int pinnedOrder;
  final int isAd;
  final String extension;
  final String status;
  final String messageLink;
  final int createdAt;
  final int updatedAt;
  final List<MomentMediaDto> media;
  final Map<String, int> reactions;
  final String? selectedReaction;
  factory MomentDto.fromJson(Map<String, dynamic> json) => MomentDto(
    id: _int(json['id']),
    content: _string(json['content']),
    tags: _string(json['tags']),
    pinnedOrder: _int(json['pinned_order']),
    isAd: _int(json['is_ad']),
    extension: _string(json['extension']),
    status: _string(json['status']),
    messageLink: _string(json['message_link']),
    createdAt: _int(json['created_at']),
    updatedAt: _int(json['updated_at']),
    media: _list(json['media']).map(MomentMediaDto.fromJson).toList(),
    reactions: _map(json['reactions']),
    selectedReaction: json['selected_reaction']?.toString(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'tags': tags,
    'pinned_order': pinnedOrder,
    'is_ad': isAd,
    'extension': extension,
    'status': status,
    'message_link': messageLink,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'media': media.map((item) => item.toJson()).toList(),
    'reactions': reactions,
    if (selectedReaction != null) 'selected_reaction': selectedReaction,
  };
}

class MomentsPage {
  const MomentsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<MomentDto> items;
  final int total;
  final int page;
  final int pageSize;
  factory MomentsPage.fromJson(Map<String, dynamic> json) => MomentsPage(
    items: _list(
      json['items'] ?? json['moments'],
    ).map(MomentDto.fromJson).toList(),
    total: _int(json['total']),
    page: _int(json['page']) == 0 ? 1 : _int(json['page']),
    pageSize: _int(json['page_size']) == 0 ? 10 : _int(json['page_size']),
  );
  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'total': total,
    'page': page,
    'page_size': pageSize,
  };
}

class CreateMediaPayload {
  const CreateMediaPayload({
    required this.mediaUrl,
    required this.mediaType,
    this.isLocal,
    this.name,
  });
  final String mediaUrl;
  final String mediaType;
  final int? isLocal;
  final String? name;
  Map<String, dynamic> toJson() => {
    'media_url': mediaUrl,
    'media_type': mediaType,
    if (isLocal != null) 'is_local': isLocal,
    if (name != null) 'name': name,
  };
}

class CreateMomentPayload {
  const CreateMomentPayload({
    required this.content,
    this.media = const [],
    this.tags,
    this.pinnedOrder,
    this.isAd,
    this.extension,
    this.guildId,
    this.channelId,
    this.messageId,
    this.messageLink,
  });
  final String content;
  final List<CreateMediaPayload> media;
  final String? tags;
  final int? pinnedOrder;
  final int? isAd;
  final String? extension;
  final int? guildId;
  final int? channelId;
  final int? messageId;
  final String? messageLink;
  Map<String, dynamic> toJson() => {
    'content': content,
    'media': media.map((item) => item.toJson()).toList(),
    if (tags != null) 'tags': tags,
    if (pinnedOrder != null) 'pinned_order': pinnedOrder,
    if (isAd != null) 'is_ad': isAd,
    if (extension != null) 'extension': extension,
    if (guildId != null) 'guild_id': guildId,
    if (channelId != null) 'channel_id': channelId,
    if (messageId != null) 'message_id': messageId,
    if (messageLink != null) 'message_link': messageLink,
  };
}

class UpdateMomentPayload {
  const UpdateMomentPayload({
    this.content,
    this.status,
    this.tags,
    this.pinnedOrder,
    this.isAd,
    this.extension,
    this.guildId,
    this.channelId,
    this.messageId,
    this.messageLink,
  });
  final String? content;
  final String? status;
  final String? tags;
  final int? pinnedOrder;
  final int? isAd;
  final String? extension;
  final int? guildId;
  final int? channelId;
  final int? messageId;
  final String? messageLink;
  Map<String, dynamic> toJson() => {
    if (content != null) 'content': content,
    if (status != null) 'status': status,
    if (tags != null) 'tags': tags,
    if (pinnedOrder != null) 'pinned_order': pinnedOrder,
    if (isAd != null) 'is_ad': isAd,
    if (extension != null) 'extension': extension,
    if (guildId != null) 'guild_id': guildId,
    if (channelId != null) 'channel_id': channelId,
    if (messageId != null) 'message_id': messageId,
    if (messageLink != null) 'message_link': messageLink,
  };
}

class MomentsApi {
  const MomentsApi({required this.client});
  static const allowedReactions = ['👍', '👎', '❤', '👀', '💩'];
  final ApiClient client;
  Future<MomentsPage> list({
    int page = 1,
    int pageSize = 10,
    bool admin = false,
  }) async {
    final body = await client.get(
      admin ? 'action/moments' : 'public/moments/',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (!admin) 'status': 'visible',
      },
    );
    return MomentsPage.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<void> create(CreateMomentPayload payload) async {
    await client.post('action/moments', data: payload.toJson());
  }

  Future<void> update(int id, UpdateMomentPayload payload) async {
    await client.put('action/moments/$id', data: payload.toJson());
  }

  Future<void> delete(int id) async {
    await client.delete('action/moments/$id');
  }

  Future<void> addReaction(int id, String reaction) async {
    if (!allowedReactions.contains(reaction)) {
      throw const ApiException(message: '不支持的 reaction', statusCode: 400);
    }
    await client.ensureFingerprintToken();
    await client.post(
      'public/moments/$id/reactions',
      data: {'reaction': reaction},
    );
  }

  Future<void> removeReaction(int id, String reaction) async {
    if (!allowedReactions.contains(reaction)) {
      throw const ApiException(message: '不支持的 reaction', statusCode: 400);
    }
    await client.ensureFingerprintToken();
    await client.delete(
      'public/moments/$id/reactions',
      data: {'reaction': reaction},
    );
  }

  Future<void> createMedia(int momentId, CreateMediaPayload media) async {
    await client.post(
      'action/moments/media',
      data: {
        'moment_id': momentId,
        ...media.toJson(),
        'is_local': media.isLocal ?? 0,
      },
    );
  }

  Future<void> deleteMedia(int id) async {
    await client.delete('action/moments/media/$id');
  }
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String _string(Object? value) => value?.toString() ?? '';
List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const [];
Map<String, int> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), _int(item)))
    : const {};
