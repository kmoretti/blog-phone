import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blog_phone/core/storage/database_settings_store.dart';
import 'package:blog_phone/data/db/app_database.dart';
import 'package:blog_phone/data/db/auth_session_store.dart';
import 'package:blog_phone/data/db/database_migrations.dart';
import 'package:blog_phone/data/db/models.dart';
import 'package:blog_phone/data/db/outbox_dao.dart';

import 'v1_schema.dart';

void main() {
  late String databasePath;
  late AppDatabase appDatabase;

  setUp(() {
    sqfliteFfiInit();
    databasePath = path.join(
      Directory.systemTemp.path,
      'blog_phone_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    Directory(databasePath).createSync();
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePathProvider: () async => databasePath,
    );
  });

  tearDown(() async {
    await appDatabase.close();
    final directory = Directory(databasePath);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test(
    'creates the complete schema with columns, types, constraints, indexes',
    () async {
      final database = await appDatabase.database;
      final expected = <String, Map<String, String>>{
        'app_settings': {'key': 'TEXT', 'value': 'TEXT', 'updated_at': 'TEXT'},
        'auth_session': {
          'id': 'INTEGER',
          'token': 'TEXT',
          'base_url': 'TEXT',
          'expires_at': 'TEXT',
          'user_id': 'TEXT',
          'updated_at': 'TEXT',
        },
        'moments': {
          'id': 'TEXT',
          'content': 'TEXT',
          'tags': 'TEXT',
          'pinned_order': 'INTEGER',
          'is_ad': 'INTEGER',
          'extension': 'TEXT',
          'status': 'TEXT',
          'guild_id': 'INTEGER',
          'channel_id': 'INTEGER',
          'message_id': 'INTEGER',
          'message_link': 'TEXT',
          'created_at': 'INTEGER',
          'updated_at': 'INTEGER',
          'cache_scope': 'TEXT',
          'cache_page': 'INTEGER',
          'cache_page_size': 'INTEGER',
        },
        'moment_media': {
          'id': 'INTEGER',
          'moment_id': 'TEXT',
          'name': 'TEXT',
          'media_url': 'TEXT',
          'media_type': 'TEXT',
          'is_local': 'INTEGER',
          'is_deleted': 'INTEGER',
          'cache_scope': 'TEXT',
          'cache_page': 'INTEGER',
          'cache_page_size': 'INTEGER',
        },
        'moment_reactions': {
          'id': 'INTEGER',
          'moment_id': 'TEXT',
          'fingerprint_id': 'INTEGER',
          'reaction': 'TEXT',
          'created_at': 'INTEGER',
          'cache_scope': 'TEXT',
          'cache_page': 'INTEGER',
          'cache_page_size': 'INTEGER',
        },
        'friend_links': {
          'id': 'INTEGER',
          'name': 'TEXT',
          'link': 'TEXT',
          'avatar': 'TEXT',
          'info': 'TEXT',
          'status': 'TEXT',
          'updated_at': 'INTEGER',
        },
        'friend_link_groups': {
          'id': 'INTEGER',
          'name': 'TEXT',
          'description': 'TEXT',
          'sort_order': 'INTEGER',
          'created_at': 'INTEGER',
          'updated_at': 'INTEGER',
        },
        'friend_link_group_mapping': {
          'id': 'INTEGER',
          'friend_link_id': 'INTEGER',
          'friend_link_group_id': 'INTEGER',
        },
        'friend_link_cache': {
          'cache_key': 'TEXT',
          'payload': 'TEXT',
          'updated_at': 'INTEGER',
        },
        'rss_feeds': {'id': 'INTEGER', 'name': 'TEXT', 'rss_url': 'TEXT'},
        'rss_posts': {
          'id': 'INTEGER',
          'rss_id': 'INTEGER',
          'title': 'TEXT',
          'link': 'TEXT',
          'description': 'TEXT',
          'author': 'TEXT',
          'time': 'INTEGER',
        },
        'images': {
          'id': 'INTEGER',
          'name': 'TEXT',
          'url': 'TEXT',
          'local_path': 'TEXT',
          'is_local': 'INTEGER',
          'is_oss': 'INTEGER',
          'status': 'TEXT',
        },
        'drafts': {
          'id': 'TEXT',
          'content': 'TEXT',
          'status': 'TEXT',
          'media_json': 'TEXT',
          'created_at': 'INTEGER',
          'updated_at': 'INTEGER',
        },
        'outbox': {
          'id': 'TEXT',
          'operation': 'TEXT',
          'payload': 'TEXT',
          'status': 'TEXT',
          'retry_count': 'INTEGER',
          'last_error': 'TEXT',
          'created_at': 'TEXT',
          'updated_at': 'TEXT',
          'processed_at': 'TEXT',
        },
      };
      final nullable = <String, Set<String>>{
        'app_settings': {'key'},
        'auth_session': {'id', 'user_id'},
        'moments': {'guild_id', 'channel_id', 'message_id'},
        'moment_media': {'id'},
        'moment_reactions': {'id'},
        'friend_links': {'id'},
        'friend_link_groups': {'id'},
        'friend_link_group_mapping': {'id'},
        'friend_link_cache': {'cache_key'},
        'rss_feeds': {'id'},
        'rss_posts': {'id'},
        'images': {'id'},
        'drafts': {'id'},
        'outbox': {'id', 'last_error', 'processed_at'},
      };
      final defaults = <String, Map<String, Object?>>{
        'moments': {
          'tags': "''",
          'pinned_order': '0',
          'is_ad': '0',
          'extension': "''",
          'message_link': "''",
          'cache_scope': "'guest'",
          'cache_page': '1',
          'cache_page_size': '10',
        },
        'moment_media': {
          'name': "''",
          'is_local': '0',
          'is_deleted': '0',
          'cache_scope': "'guest'",
          'cache_page': '1',
          'cache_page_size': '10',
        },
        'moment_reactions': {
          'cache_scope': "'guest'",
          'cache_page': '1',
          'cache_page_size': '10',
        },
        'friend_links': {'status': "''"},
        'friend_link_groups': {'sort_order': '0'},
        'drafts': {},
        'outbox': {'retry_count': '0'},
      };
      for (final entry in expected.entries) {
        final rows = await database.rawQuery('PRAGMA table_info(${entry.key})');
        expect(
          rows.map((row) => row['name']).toList(),
          entry.value.keys.toList(),
        );
        for (final column in entry.value.entries) {
          final row = rows.firstWhere((row) => row['name'] == column.key);
          expect(row['type'], column.value);
          expect(
            row['notnull'],
            nullable[entry.key]?.contains(column.key) == true ? 0 : 1,
            reason: '${entry.key}.${column.key}',
          );
          final expectedDefault = defaults[entry.key]?[column.key];
          if (expectedDefault != null) {
            expect(row['dflt_value'], expectedDefault);
          }
        }
      }
      expect(
        (await database.rawQuery(
          'PRAGMA table_info(auth_session)',
        )).firstWhere((row) => row['name'] == 'id')['pk'],
        1,
      );
      final momentPrimaryKeys = await database.rawQuery(
        'PRAGMA table_info(moments)',
      );
      expect(
        momentPrimaryKeys
            .where((row) => row['pk'] != 0)
            .map((row) => row['name'])
            .toList(),
        ['id', 'cache_scope', 'cache_page', 'cache_page_size'],
      );
      expect(
        (await database.rawQuery(
          'PRAGMA table_info(outbox)',
        )).firstWhere((row) => row['name'] == 'id')['pk'],
        1,
      );
      expect(
        (await database.rawQuery(
          'PRAGMA index_list(outbox)',
        )).map((row) => row['name']),
        contains('outbox_status_created_idx'),
      );
      expect(
        (await database.rawQuery(
          'PRAGMA index_list(friend_link_group_mapping)',
        )).map((row) => row['unique']),
        contains(1),
      );
      expect(
        (await database.rawQuery(
          'SELECT sql FROM sqlite_master WHERE name = ?',
          ['auth_session'],
        )).single['sql'],
        contains('CHECK (id = 1)'),
      );
    },
  );

  test('upgrades v1 friend link schema and creates cache schema', () async {
    final databaseFile = path.join(databasePath, 'blog_phone.db');
    final v1 = await databaseFactoryFfi.openDatabase(
      databaseFile,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final statement in v1Schema) {
            await db.execute(statement);
          }
        },
      ),
    );
    await v1.close();

    final upgraded = await appDatabase.database;
    final friendLinkColumns = await upgraded.rawQuery(
      'PRAGMA table_info(friend_links)',
    );
    expect(
      friendLinkColumns.map((row) => row['name']),
      contains('status'),
    );
    expect(
      friendLinkColumns.firstWhere((row) => row['name'] == 'status')['notnull'],
      1,
    );
    expect(
      (await upgraded.rawQuery('PRAGMA table_info(friend_link_cache)'))
          .map((row) => row['name']),
      ['cache_key', 'payload', 'updated_at'],
    );
  });

  test(
    'opens a real v1 database file with AppDatabase and runs upgrade',
    () async {
      final v1 = await databaseFactoryFfi.openDatabase(
        databasePath == inMemoryDatabasePath
            ? inMemoryDatabasePath
            : path.join(databasePath, 'blog_phone.db'),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            for (final statement in v1Schema) {
              await db.execute(statement);
            }
            await db.insert('moment_media', {
              'id': 1,
              'moment_id': 42,
              'media_url': 'https://media.test',
              'media_type': 'image',
              'is_local': 0,
            });
          },
        ),
      );
      await v1.close();
      final upgraded = await appDatabase.database;
      expect((await upgraded.query('moment_media')).single['moment_id'], '42');
      expect((await upgraded.query('moment_media')).single['is_deleted'], 0);
      expect(
        (await upgraded.rawQuery('PRAGMA user_version')).single['user_version'],
        databaseVersion,
      );
    },
  );

  test(
    'real onUpgrade maps illegal legacy outbox status to failed',
    () async {
      final databaseFile = path.join(databasePath, 'blog_phone.db');
      final v1 = await databaseFactoryFfi.openDatabase(
        databaseFile,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            for (final statement in v1Schema) {
              await db.execute(statement);
            }
            await db.insert('moments', {
              'id': 'legacy',
              'content': 'preserved',
              'status': 'published',
              'created_at': 1,
              'updated_at': 2,
            });
            await db.insert('outbox', {
              'id': 'invalid-status',
              'operation': 'op',
              'payload': '{}',
              'status': 'illegal',
              'created_at': 'created',
              'updated_at': 'updated',
            });
          },
        ),
      );
      await v1.close();

      final upgraded = await appDatabase.database;
      expect((await upgraded.query('outbox')).single['status'], 'failed');
      await appDatabase.close();

      final inspected = await databaseFactoryFfi.openDatabase(databaseFile);
      addTearDown(inspected.close);
      expect(
        (await inspected.rawQuery(
          'PRAGMA user_version',
        )).single['user_version'],
        databaseVersion,
      );
      expect((await inspected.query('moments')).single['content'], 'preserved');
      expect((await inspected.query('outbox')).single['status'], 'failed');
      final columns = await inspected.rawQuery(
        'PRAGMA table_info(moment_media)',
      );
      expect(
        columns.firstWhere((row) => row['name'] == 'moment_id')['type'],
        'TEXT',
      );
      expect(
        (await inspected.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        )).map((row) => row['name']),
        isNot(contains('moment_media_v1')),
      );
      expect(
        (await inspected.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE '%v2%'",
        )).map((row) => row['name']),
        isEmpty,
      );
    },
  );

  test(
    'settings, auth session, and outbox survive a new AppDatabase instance',
    () async {
      final settings = DatabaseSettingsStore(appDatabase);
      final sessionStore = DatabaseAuthSessionStore(appDatabase);
      final firstDao = OutboxDao(await appDatabase.database);
      await settings.write('theme', 'dark');
      const session = AuthSession(
        token: 't',
        baseUrl: 'https://api.test',
        expiresAt: '2099-01-01T00:00:00Z',
        userId: 'u',
        updatedAt: '2026-01-01T00:00:00Z',
      );
      await sessionStore.write(session);
      await firstDao.insert(
        const OutboxItem(
          id: 'persisted',
          operation: 'sync',
          payload: '{}',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );
      await appDatabase.close();
      final reopened = AppDatabase(
        factory: databaseFactoryFfi,
        databasePathProvider: () async => databasePath,
      );
      addTearDown(reopened.close);
      expect(await DatabaseSettingsStore(reopened).read('theme'), 'dark');
      expect(
        (await DatabaseAuthSessionStore(reopened).read())!.toJson(),
        session.toJson(),
      );
      expect(
        await OutboxDao(await reopened.database).get('persisted'),
        isNotNull,
      );
    },
  );

  test('all entities round trip through JSON and rows field by field', () {
    final values = <RowJsonModel>[
      const Moment(
        id: 'm',
        content: 'c',
        tags: 't',
        pinnedOrder: 1,
        isAd: 0,
        extension: '{}',
        status: 'published',
        guildId: 2,
        channelId: 3,
        messageId: 4,
        messageLink: 'l',
        createdAt: 5,
        updatedAt: 6,
      ),
      const FriendLink(
        id: 1,
        name: 'n',
        link: 'l',
        avatar: 'a',
        info: 'i',
        status: 's',
        updatedAt: 2,
      ),
      const FriendLinkGroup(
        id: 2,
        name: 'g',
        description: 'd',
        sortOrder: 1,
        createdAt: 2,
        updatedAt: 3,
      ),
      const FriendLinkGroupMapping(
        id: 3,
        friendLinkId: 1,
        friendLinkGroupId: 2,
      ),
      const RssFeed(id: 4, name: 'f', rssUrl: 'u'),
      const RssPost(
        id: 5,
        rssId: 4,
        title: 't',
        link: 'l',
        description: 'd',
        author: 'a',
        time: 6,
      ),
      const Image(
        id: 6,
        name: 'i',
        url: 'u',
        localPath: 'p',
        isLocal: 0,
        isOss: 1,
        status: 'ready',
      ),
      const Draft(
        id: 'd',
        content: 'c',
        status: 'draft',
        mediaJson: '[]',
        createdAt: 1,
        updatedAt: 2,
      ),
      const AuthSession(
        token: 't',
        baseUrl: 'u',
        expiresAt: 'e',
        userId: 'u',
        updatedAt: 'a',
      ),
      const Media(
        id: 7,
        momentId: 'm',
        name: 'n',
        mediaUrl: 'u',
        mediaType: 'image',
        isLocal: 0,
        isDeleted: 1,
      ),
      const Reaction(
        id: 8,
        momentId: 'm',
        fingerprintId: 2,
        reaction: 'like',
        createdAt: 1,
      ),
      const OutboxItem(
        id: 'o',
        operation: 'op',
        payload: '{}',
        createdAt: '2026-01-01T00:00:00Z',
        lastError: 'e',
        processedAt: '2026-01-02T00:00:00Z',
      ),
    ];
    for (final value in values) {
      expect(value.runtimeType.toString(), isNotEmpty);
      expect(value.toJson(), isNotEmpty);
      expect(value.toRow(), isNotEmpty);
      expect(value.toJson(), value.toRow());
    }
    expect(Moment.fromJson(values[0].toJson()).toJson(), values[0].toJson());
    expect(Moment.fromRow(values[0].toRow()).toJson(), values[0].toJson());
    expect(
      FriendLink.fromJson(values[1].toJson()).toJson(),
      values[1].toJson(),
    );
    expect(FriendLink.fromRow(values[1].toRow()).toJson(), values[1].toJson());
    expect(
      FriendLinkGroup.fromJson(values[2].toJson()).toJson(),
      values[2].toJson(),
    );
    expect(
      FriendLinkGroup.fromRow(values[2].toRow()).toJson(),
      values[2].toJson(),
    );
    expect(
      FriendLinkGroupMapping.fromJson(values[3].toJson()).toJson(),
      values[3].toJson(),
    );
    expect(
      FriendLinkGroupMapping.fromRow(values[3].toRow()).toJson(),
      values[3].toJson(),
    );
    expect(RssFeed.fromJson(values[4].toJson()).toJson(), values[4].toJson());
    expect(RssFeed.fromRow(values[4].toRow()).toJson(), values[4].toJson());
    expect(RssPost.fromJson(values[5].toJson()).toJson(), values[5].toJson());
    expect(RssPost.fromRow(values[5].toRow()).toJson(), values[5].toJson());
    expect(Image.fromJson(values[6].toJson()).toJson(), values[6].toJson());
    expect(Image.fromRow(values[6].toRow()).toJson(), values[6].toJson());
    expect(Draft.fromJson(values[7].toJson()).toJson(), values[7].toJson());
    expect(Draft.fromRow(values[7].toRow()).toJson(), values[7].toJson());
    expect(
      AuthSession.fromJson(values[8].toJson()).toJson(),
      values[8].toJson(),
    );
    expect(AuthSession.fromRow(values[8].toRow()).toJson(), values[8].toJson());
    expect(Media.fromJson(values[9].toJson()).toJson(), values[9].toJson());
    expect(Media.fromRow(values[9].toRow()).toJson(), values[9].toJson());
    expect(
      Reaction.fromJson(values[10].toJson()).toJson(),
      values[10].toJson(),
    );
    expect(Reaction.fromRow(values[10].toRow()).toJson(), values[10].toJson());
    expect(
      OutboxItem.fromJson(values[11].toJson()).toJson(),
      values[11].toJson(),
    );
    expect(
      OutboxItem.fromRow(values[11].toRow()).toJson(),
      values[11].toJson(),
    );
  });

  test('auth session round trips field by field through real SQLite', () async {
    final database = await appDatabase.database;
    const expected = AuthSession(
      token: 'session-token',
      baseUrl: 'https://api.test',
      expiresAt: '2099-01-01T00:00:00Z',
      userId: 'user-1',
      updatedAt: '2026-01-01T00:00:00Z',
    );
    await database.insert('auth_session', expected.toRow());
    final row = (await database.query('auth_session', where: 'id = 1')).single;
    final actual = AuthSession.fromRow(row);
    expect(row['token'], expected.token);
    expect(row['base_url'], expected.baseUrl);
    expect(row['expires_at'], expected.expiresAt);
    expect(row['user_id'], expected.userId);
    expect(row['updated_at'], expected.updatedAt);
    expect(actual.toJson(), expected.toJson());
  });

  test('outbox item round trips field by field through real SQLite', () async {
    final database = await appDatabase.database;
    const expected = OutboxItem(
      id: 'outbox-sql',
      operation: 'sync',
      payload: '{"id":1}',
      status: OutboxStatus.failed,
      retryCount: 3,
      lastError: 'network',
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:01:00Z',
      processedAt: '2026-01-01T00:02:00Z',
    );
    await database.insert('outbox', expected.toRow());
    final row = (await database.query(
      'outbox',
      where: 'id = ?',
      whereArgs: [expected.id],
    )).single;
    final actual = OutboxItem.fromRow(row);
    expect(row['id'], expected.id);
    expect(row['operation'], expected.operation);
    expect(row['payload'], expected.payload);
    expect(row['status'], expected.status);
    expect(row['retry_count'], expected.retryCount);
    expect(row['last_error'], expected.lastError);
    expect(row['created_at'], expected.createdAt);
    expect(row['updated_at'], expected.updatedAt);
    expect(row['processed_at'], expected.processedAt);
    expect(actual.toJson(), expected.toJson());
  });

  test('all persisted entities round trip through real SQLite rows', () async {
    final database = await appDatabase.database;
    final entities = <String, RowJsonModel>{
      'moments': const Moment(
        id: 'm-sql',
        content: 'content',
        tags: 'tag',
        pinnedOrder: 1,
        isAd: 0,
        extension: '{}',
        status: 'published',
        guildId: 2,
        channelId: 3,
        messageId: 4,
        messageLink: 'link',
        createdAt: 5,
        updatedAt: 6,
      ),
      'moment_media': const Media(
        id: 7,
        momentId: 'm-sql',
        name: 'media',
        mediaUrl: 'url',
        mediaType: 'image',
        isLocal: 0,
        isDeleted: 1,
      ),
      'moment_reactions': const Reaction(
        id: 8,
        momentId: 'm-sql',
        fingerprintId: 2,
        reaction: 'like',
        createdAt: 9,
      ),
      'friend_links': const FriendLink(
        id: 10,
        name: 'name',
        link: 'link',
        avatar: 'avatar',
        info: 'info',
        status: 'ok',
        updatedAt: 11,
      ),
      'friend_link_groups': const FriendLinkGroup(
        id: 12,
        name: 'group',
        description: 'description',
        sortOrder: 1,
        createdAt: 13,
        updatedAt: 14,
      ),
      'friend_link_group_mapping': const FriendLinkGroupMapping(
        id: 15,
        friendLinkId: 10,
        friendLinkGroupId: 12,
      ),
      'rss_feeds': const RssFeed(id: 16, name: 'feed', rssUrl: 'rss'),
      'rss_posts': const RssPost(
        id: 17,
        rssId: 16,
        title: 'title',
        link: 'link',
        description: 'desc',
        author: 'author',
        time: 18,
      ),
      'images': const Image(
        id: 19,
        name: 'image',
        url: 'url',
        localPath: 'path',
        isLocal: 0,
        isOss: 1,
        status: 'ready',
      ),
      'drafts': const Draft(
        id: 'draft-sql',
        content: 'draft',
        status: 'draft',
        mediaJson: '[]',
        createdAt: 20,
        updatedAt: 21,
      ),
    };
    for (final entry in entities.entries) {
      await database.insert(entry.key, entry.value.toRow());
    }
    final decoded = <RowJsonModel>[
      Moment.fromRow(
        (await database.query(
          'moments',
          where: 'id = ?',
          whereArgs: ['m-sql'],
        )).single,
      ),
      Media.fromRow(
        (await database.query(
          'moment_media',
          where: 'id = ?',
          whereArgs: [7],
        )).single,
      ),
      Reaction.fromRow(
        (await database.query(
          'moment_reactions',
          where: 'id = ?',
          whereArgs: [8],
        )).single,
      ),
      FriendLink.fromRow(
        (await database.query(
          'friend_links',
          where: 'id = ?',
          whereArgs: [10],
        )).single,
      ),
      FriendLinkGroup.fromRow(
        (await database.query(
          'friend_link_groups',
          where: 'id = ?',
          whereArgs: [12],
        )).single,
      ),
      FriendLinkGroupMapping.fromRow(
        (await database.query(
          'friend_link_group_mapping',
          where: 'id = ?',
          whereArgs: [15],
        )).single,
      ),
      RssFeed.fromRow(
        (await database.query(
          'rss_feeds',
          where: 'id = ?',
          whereArgs: [16],
        )).single,
      ),
      RssPost.fromRow(
        (await database.query(
          'rss_posts',
          where: 'id = ?',
          whereArgs: [17],
        )).single,
      ),
      Image.fromRow(
        (await database.query(
          'images',
          where: 'id = ?',
          whereArgs: [19],
        )).single,
      ),
      Draft.fromRow(
        (await database.query(
          'drafts',
          where: 'id = ?',
          whereArgs: ['draft-sql'],
        )).single,
      ),
    ];
    expect(
      decoded.map((item) => item.toJson()).toList(),
      entities.values.map((item) => item.toJson()).toList(),
    );
  });
  test(
    'new instance automatically recovers an expired processing lease',
    () async {
      await appDatabase.close();
      final first = AppDatabase(
        factory: databaseFactoryFfi,
        databasePathProvider: () async => databasePath,
      );
      final firstDao = OutboxDao(await first.database);
      await firstDao.insert(
        const OutboxItem(
          id: 'auto-expired',
          operation: 'op',
          payload: '{}',
          status: OutboxStatus.processing,
          createdAt: '2026-01-01T00:00:00Z',
          updatedAt: '2025-12-31T23:00:00Z',
        ),
      );
      await first.close();
      final second = AppDatabase(
        factory: databaseFactoryFfi,
        databasePathProvider: () async => databasePath,
      );
      addTearDown(second.close);
      expect(
        (await OutboxDao(await second.database).get('auto-expired'))!.status,
        OutboxStatus.failed,
      );
    },
  );

  test(
    'recovery marks only expired processing items and database open invokes it',
    () async {
      final dao = OutboxDao(await appDatabase.database);
      final now = DateTime.utc(2026, 1, 1, 0, 10);
      await dao.insert(
        const OutboxItem(
          id: 'expired',
          operation: 'op',
          payload: '{}',
          status: OutboxStatus.processing,
          createdAt: '2026-01-01T00:00:00Z',
          updatedAt: '2025-12-31T23:59:00Z',
        ),
      );
      await dao.insert(
        const OutboxItem(
          id: 'fresh',
          operation: 'op',
          payload: '{}',
          status: OutboxStatus.processing,
          createdAt: '2026-01-01T00:00:00Z',
          updatedAt: '2026-01-01T00:09:00Z',
        ),
      );
      expect(
        await appDatabase.recoverExpiredProcessing(
          timeout: const Duration(minutes: 5),
          now: now,
        ),
        1,
      );
      expect((await dao.get('expired'))!.status, OutboxStatus.failed);
      expect((await dao.get('fresh'))!.status, OutboxStatus.processing);
    },
  );

  test('SQLite rejects illegal outbox status', () async {
    final database = await appDatabase.database;
    await expectLater(
      database.insert('outbox', {
        'id': 'bad-sql',
        'operation': 'op',
        'payload': '{}',
        'status': 'illegal',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'outbox rejects illegal states and safely handles completed or paused items',
    () async {
      final dao = OutboxDao(await appDatabase.database);
      expect(
        () => dao.insert(
          const OutboxItem(
            id: 'bad',
            operation: 'op',
            payload: '{}',
            status: 'illegal',
            createdAt: 'x',
          ),
        ),
        throwsArgumentError,
      );
      await dao.insert(
        const OutboxItem(
          id: 'completed',
          operation: 'op',
          payload: '{}',
          status: OutboxStatus.completed,
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );
      await dao.insert(
        const OutboxItem(
          id: 'paused',
          operation: 'op',
          payload: '{}',
          status: OutboxStatus.pausedAuth,
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );
      expect(await dao.claimProcessing(), isEmpty);
      expect(await dao.markSucceeded('completed'), isFalse);
      expect(await dao.markFailed('paused', 'x'), isFalse);
      expect(await dao.retry('completed'), isFalse);
    },
  );
}
