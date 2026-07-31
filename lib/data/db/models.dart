abstract interface class RowJsonModel {
  Map<String, Object?> toRow();
  Map<String, dynamic> toJson();
}

String _string(Object? value) => value?.toString() ?? '';
int _int(Object? value) => (value as num?)?.toInt() ?? 0;
String? _nullableString(Object? value) => value?.toString();
int? _nullableInt(Object? value) => (value as num?)?.toInt();

class Moment implements RowJsonModel {
  const Moment({
    required this.id,
    required this.content,
    required this.tags,
    required this.pinnedOrder,
    required this.isAd,
    required this.extension,
    required this.status,
    required this.guildId,
    required this.channelId,
    required this.messageId,
    required this.messageLink,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, content, tags, extension, status, messageLink;
  final int pinnedOrder, isAd, createdAt, updatedAt;
  final int? guildId, channelId, messageId;
  factory Moment.fromJson(Map<String, dynamic> json) => Moment(
    id: _string(json['id']),
    content: _string(json['content']),
    tags: _string(json['tags']),
    pinnedOrder: _int(json['pinned_order']),
    isAd: _int(json['is_ad']),
    extension: _string(json['extension']),
    status: _string(json['status']),
    guildId: _nullableInt(json['guild_id']),
    channelId: _nullableInt(json['channel_id']),
    messageId: _nullableInt(json['message_id']),
    messageLink: _string(json['message_link']),
    createdAt: _int(json['created_at']),
    updatedAt: _int(json['updated_at']),
  );
  factory Moment.fromRow(Map<String, Object?> row) =>
      Moment.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'tags': tags,
    'pinned_order': pinnedOrder,
    'is_ad': isAd,
    'extension': extension,
    'status': status,
    'guild_id': guildId,
    'channel_id': channelId,
    'message_id': messageId,
    'message_link': messageLink,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

class FriendLink implements RowJsonModel {
  const FriendLink({
    required this.id,
    required this.name,
    required this.link,
    required this.avatar,
    required this.info,
    this.status = '',
    required this.updatedAt,
  });
  final int id, updatedAt;
  final String name, link, avatar, info, status;
  factory FriendLink.fromJson(Map<String, dynamic> json) => FriendLink(
    id: _int(json['id']),
    name: _string(json['name']),
    link: _string(json['link']),
    avatar: _string(json['avatar']),
    info: _string(json['info']),
    status: _string(json['status']),
    updatedAt: _int(json['updated_at']),
  );
  factory FriendLink.fromRow(Map<String, Object?> row) =>
      FriendLink.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'link': link,
    'avatar': avatar,
    'info': info,
    'status': status,
    'updated_at': updatedAt,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

class FriendLinkGroup implements RowJsonModel {
  const FriendLinkGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  final int id, sortOrder, createdAt, updatedAt;
  final String name, description;
  factory FriendLinkGroup.fromJson(Map<String, dynamic> json) =>
      FriendLinkGroup(
        id: _int(json['id']),
        name: _string(json['name']),
        description: _string(json['description']),
        sortOrder: _int(json['sort_order']),
        createdAt: _int(json['created_at']),
        updatedAt: _int(json['updated_at']),
      );
  factory FriendLinkGroup.fromRow(Map<String, Object?> row) =>
      FriendLinkGroup.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'sort_order': sortOrder,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

class FriendLinkGroupMapping implements RowJsonModel {
  const FriendLinkGroupMapping({
    required this.id,
    required this.friendLinkId,
    required this.friendLinkGroupId,
  });
  final int id, friendLinkId, friendLinkGroupId;
  factory FriendLinkGroupMapping.fromJson(Map<String, dynamic> json) =>
      FriendLinkGroupMapping(
        id: _int(json['id']),
        friendLinkId: _int(json['friend_link_id']),
        friendLinkGroupId: _int(json['friend_link_group_id']),
      );
  factory FriendLinkGroupMapping.fromRow(Map<String, Object?> row) =>
      FriendLinkGroupMapping.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'friend_link_id': friendLinkId,
    'friend_link_group_id': friendLinkGroupId,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

class RssFeed implements RowJsonModel {
  const RssFeed({required this.id, required this.name, required this.rssUrl});
  final int id;
  final String name, rssUrl;
  factory RssFeed.fromJson(Map<String, dynamic> json) => RssFeed(
    id: _int(json['id']),
    name: _string(json['name']),
    rssUrl: _string(json['rss_url']),
  );
  factory RssFeed.fromRow(Map<String, Object?> row) =>
      RssFeed.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'rss_url': rssUrl};
  @override
  Map<String, Object?> toRow() => toJson();
}

class RssPost implements RowJsonModel {
  const RssPost({
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
  factory RssPost.fromJson(Map<String, dynamic> json) => RssPost(
    id: _int(json['id']),
    rssId: _int(json['rss_id']),
    title: _string(json['title']),
    link: _string(json['link']),
    description: _string(json['description']),
    author: _string(json['author']),
    time: _int(json['time']),
  );
  factory RssPost.fromRow(Map<String, Object?> row) =>
      RssPost.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'rss_id': rssId,
    'title': title,
    'link': link,
    'description': description,
    'author': author,
    'time': time,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

class Image implements RowJsonModel {
  const Image({
    required this.id,
    required this.name,
    required this.url,
    required this.localPath,
    required this.isLocal,
    required this.isOss,
    required this.status,
  });
  final int id, isLocal, isOss;
  final String name, url, localPath, status;
  factory Image.fromJson(Map<String, dynamic> json) => Image(
    id: _int(json['id']),
    name: _string(json['name']),
    url: _string(json['url']),
    localPath: _string(json['local_path']),
    isLocal: _int(json['is_local']),
    isOss: _int(json['is_oss']),
    status: _string(json['status']),
  );
  factory Image.fromRow(Map<String, Object?> row) =>
      Image.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'local_path': localPath,
    'is_local': isLocal,
    'is_oss': isOss,
    'status': status,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

class Draft implements RowJsonModel {
  const Draft({
    required this.id,
    required this.content,
    required this.status,
    required this.mediaJson,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, content, status, mediaJson;
  final int createdAt, updatedAt;
  factory Draft.fromJson(Map<String, dynamic> json) => Draft(
    id: _string(json['id']),
    content: _string(json['content']),
    status: _string(json['status']),
    mediaJson: _string(json['media_json']),
    createdAt: _int(json['created_at']),
    updatedAt: _int(json['updated_at']),
  );
  factory Draft.fromRow(Map<String, Object?> row) =>
      Draft.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'status': status,
    'media_json': mediaJson,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

class AuthSession implements RowJsonModel {
  const AuthSession({
    required this.token,
    required this.baseUrl,
    required this.expiresAt,
    this.userId,
    required this.updatedAt,
  });
  final String token, baseUrl, expiresAt, updatedAt;
  final String? userId;
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: _string(json['token']),
    baseUrl: _string(json['base_url']),
    expiresAt: _string(json['expires_at']),
    userId: _nullableString(json['user_id']),
    updatedAt: _string(json['updated_at']),
  );
  factory AuthSession.fromRow(Map<String, Object?> row) =>
      AuthSession.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': 1,
    'token': token,
    'base_url': baseUrl,
    'expires_at': expiresAt,
    'user_id': userId,
    'updated_at': updatedAt,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

class Media implements RowJsonModel {
  const Media({
    required this.id,
    required this.momentId,
    required this.name,
    required this.mediaUrl,
    required this.mediaType,
    required this.isLocal,
    required this.isDeleted,
  });
  final int id, isLocal, isDeleted;
  final String momentId, name, mediaUrl, mediaType;
  factory Media.fromJson(Map<String, dynamic> json) => Media(
    id: _int(json['id']),
    momentId: _string(json['moment_id']),
    name: _string(json['name']),
    mediaUrl: _string(json['media_url']),
    mediaType: _string(json['media_type']),
    isLocal: _int(json['is_local']),
    isDeleted: _int(json['is_deleted']),
  );
  factory Media.fromRow(Map<String, Object?> row) =>
      Media.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'moment_id': momentId,
    'name': name,
    'media_url': mediaUrl,
    'media_type': mediaType,
    'is_local': isLocal,
    'is_deleted': isDeleted,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

class Reaction implements RowJsonModel {
  const Reaction({
    required this.id,
    required this.momentId,
    required this.fingerprintId,
    required this.reaction,
    required this.createdAt,
  });
  final int id, fingerprintId, createdAt;
  final String momentId, reaction;
  factory Reaction.fromJson(Map<String, dynamic> json) => Reaction(
    id: _int(json['id']),
    momentId: _string(json['moment_id']),
    fingerprintId: _int(json['fingerprint_id']),
    reaction: _string(json['reaction']),
    createdAt: _int(json['created_at']),
  );
  factory Reaction.fromRow(Map<String, Object?> row) =>
      Reaction.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'moment_id': momentId,
    'fingerprint_id': fingerprintId,
    'reaction': reaction,
    'created_at': createdAt,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

class OutboxItem implements RowJsonModel {
  const OutboxItem({
    required this.id,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.status = OutboxStatus.pending,
    this.retryCount = 0,
    this.lastError,
    String? updatedAt,
    this.processedAt,
  }) : updatedAt = updatedAt ?? createdAt;
  final String id, operation, payload, status, createdAt, updatedAt;
  final int retryCount;
  final String? lastError, processedAt;
  factory OutboxItem.fromJson(Map<String, dynamic> json) => OutboxItem(
    id: _string(json['id']),
    operation: _string(json['operation']),
    payload: _string(json['payload']),
    status: _string(json['status']).isEmpty
        ? OutboxStatus.pending
        : _string(json['status']),
    retryCount: _int(json['retry_count']),
    lastError: _nullableString(json['last_error']),
    createdAt: _string(json['created_at']),
    updatedAt: _nullableString(json['updated_at']),
    processedAt: _nullableString(json['processed_at']),
  );
  factory OutboxItem.fromRow(Map<String, Object?> row) =>
      OutboxItem.fromJson(row.cast<String, dynamic>());
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation,
    'payload': payload,
    'status': status,
    'retry_count': retryCount,
    'last_error': lastError,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'processed_at': processedAt,
  };
  @override
  Map<String, Object?> toRow() => toJson();
}

abstract final class OutboxStatus {
  static const pending = 'pending';
  static const processing = 'processing';
  static const failed = 'failed';
  static const pausedAuth = 'paused_auth';
  static const completed = 'completed';
}
