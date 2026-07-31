import 'package:sqflite/sqflite.dart';

const databaseVersion = 8;

Future<void> createDatabase(Database db) async {
  await db.transaction((txn) async {
    for (final statement in _createStatements) {
      await txn.execute(statement);
    }
  });
}

Future<void> migrateDatabase(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  await db.transaction((txn) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      for (final statement
          in _migrationStatements[version] ?? const <String>[]) {
        await txn.execute(statement);
      }
    }
  });
}

const _createStatements = <String>[
  'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)',
  'CREATE TABLE auth_session (id INTEGER PRIMARY KEY CHECK (id = 1), token TEXT NOT NULL, base_url TEXT NOT NULL, expires_at TEXT NOT NULL, user_id TEXT, updated_at TEXT NOT NULL)',
  'CREATE TABLE moments (id TEXT NOT NULL, content TEXT NOT NULL, tags TEXT NOT NULL DEFAULT \'\', pinned_order INTEGER NOT NULL DEFAULT 0, is_ad INTEGER NOT NULL DEFAULT 0, extension TEXT NOT NULL DEFAULT \'\', status TEXT NOT NULL, guild_id INTEGER, channel_id INTEGER, message_id INTEGER, message_link TEXT NOT NULL DEFAULT \'\', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, cache_scope TEXT NOT NULL DEFAULT \'guest\', cache_page INTEGER NOT NULL DEFAULT 1, cache_page_size INTEGER NOT NULL DEFAULT 10, PRIMARY KEY (id, cache_scope, cache_page, cache_page_size))',
  'CREATE TABLE moment_media (id INTEGER PRIMARY KEY, moment_id TEXT NOT NULL, name TEXT NOT NULL DEFAULT \'\', media_url TEXT NOT NULL, media_type TEXT NOT NULL, is_local INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0, cache_scope TEXT NOT NULL DEFAULT \'guest\', cache_page INTEGER NOT NULL DEFAULT 1, cache_page_size INTEGER NOT NULL DEFAULT 10)',
  'CREATE TABLE moment_reactions (id INTEGER PRIMARY KEY, moment_id TEXT NOT NULL, fingerprint_id INTEGER NOT NULL, reaction TEXT NOT NULL, created_at INTEGER NOT NULL, cache_scope TEXT NOT NULL DEFAULT \'guest\', cache_page INTEGER NOT NULL DEFAULT 1, cache_page_size INTEGER NOT NULL DEFAULT 10, UNIQUE(moment_id, fingerprint_id, reaction, cache_scope, cache_page, cache_page_size))',
  'CREATE TABLE friend_links (id INTEGER PRIMARY KEY, name TEXT NOT NULL, link TEXT NOT NULL, avatar TEXT NOT NULL, info TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'\', updated_at INTEGER NOT NULL)',
  'CREATE TABLE friend_link_groups (id INTEGER PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
  'CREATE TABLE friend_link_group_mapping (id INTEGER PRIMARY KEY, friend_link_id INTEGER NOT NULL, friend_link_group_id INTEGER NOT NULL, UNIQUE(friend_link_id, friend_link_group_id))',
  'CREATE TABLE friend_link_cache (cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)',
  'CREATE TABLE rss_feeds (id INTEGER PRIMARY KEY, name TEXT NOT NULL, rss_url TEXT NOT NULL)',
  'CREATE TABLE rss_feed_cache (cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)',
  'CREATE TABLE rss_post_cache (cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)',
  'CREATE TABLE image_cache (cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)',
  'CREATE TABLE rss_posts (id INTEGER PRIMARY KEY, rss_id INTEGER NOT NULL, title TEXT NOT NULL, link TEXT NOT NULL, description TEXT NOT NULL, author TEXT NOT NULL, time INTEGER NOT NULL)',
  'CREATE TABLE images (id INTEGER PRIMARY KEY, name TEXT NOT NULL, url TEXT NOT NULL, local_path TEXT NOT NULL, is_local INTEGER NOT NULL DEFAULT 0, is_oss INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL)',
  'CREATE TABLE drafts (id TEXT PRIMARY KEY, content TEXT NOT NULL, status TEXT NOT NULL, media_json TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
  'CREATE TABLE outbox (id TEXT PRIMARY KEY, operation TEXT NOT NULL, payload TEXT NOT NULL, status TEXT NOT NULL CHECK (status IN (\'pending\', \'processing\', \'failed\', \'paused_auth\', \'completed\')), retry_count INTEGER NOT NULL DEFAULT 0, last_error TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, processed_at TEXT)',
  'CREATE INDEX outbox_status_created_idx ON outbox(status, created_at)',
];

const _migrationStatements = <int, List<String>>{
  2: [
    'ALTER TABLE moments ADD COLUMN extension TEXT NOT NULL DEFAULT \'\'',
    'ALTER TABLE moment_media RENAME TO moment_media_v1',
    'CREATE TABLE moment_media (id INTEGER PRIMARY KEY, moment_id TEXT NOT NULL, name TEXT NOT NULL DEFAULT \'\', media_url TEXT NOT NULL, media_type TEXT NOT NULL, is_local INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0)',
    'INSERT INTO moment_media (id, moment_id, name, media_url, media_type, is_local) SELECT id, CAST(moment_id AS TEXT), name, media_url, media_type, is_local FROM moment_media_v1',
    'DROP TABLE moment_media_v1',
  ],
  3: [
    'ALTER TABLE outbox RENAME TO outbox_v2',
    'CREATE TABLE outbox (id TEXT PRIMARY KEY, operation TEXT NOT NULL, payload TEXT NOT NULL, status TEXT NOT NULL CHECK (status IN (\'pending\', \'processing\', \'failed\', \'paused_auth\', \'completed\')), retry_count INTEGER NOT NULL DEFAULT 0, last_error TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, processed_at TEXT)',
    'INSERT INTO outbox (id, operation, payload, status, retry_count, last_error, created_at, updated_at, processed_at) SELECT id, operation, payload, CASE WHEN status IN (\'pending\', \'processing\', \'failed\', \'paused_auth\', \'completed\') THEN status ELSE \'failed\' END, retry_count, last_error, created_at, updated_at, processed_at FROM outbox_v2',
    'DROP TABLE outbox_v2',
    'CREATE INDEX outbox_status_created_idx ON outbox(status, created_at)',
  ],
  4: [
    'ALTER TABLE moments ADD COLUMN cache_scope TEXT NOT NULL DEFAULT \'guest\'',
    'ALTER TABLE moments ADD COLUMN cache_page INTEGER NOT NULL DEFAULT 1',
    'ALTER TABLE moments ADD COLUMN cache_page_size INTEGER NOT NULL DEFAULT 10',
  ],
  5: [
    'ALTER TABLE moments RENAME TO moments_v4',
    'CREATE TABLE moments (id TEXT NOT NULL, content TEXT NOT NULL, tags TEXT NOT NULL DEFAULT \'\', pinned_order INTEGER NOT NULL DEFAULT 0, is_ad INTEGER NOT NULL DEFAULT 0, extension TEXT NOT NULL DEFAULT \'\', status TEXT NOT NULL, guild_id INTEGER, channel_id INTEGER, message_id INTEGER, message_link TEXT NOT NULL DEFAULT \'\', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, cache_scope TEXT NOT NULL DEFAULT \'guest\', cache_page INTEGER NOT NULL DEFAULT 1, cache_page_size INTEGER NOT NULL DEFAULT 10, PRIMARY KEY (id, cache_scope, cache_page, cache_page_size))',
    'INSERT INTO moments (id, content, tags, pinned_order, is_ad, extension, status, guild_id, channel_id, message_id, message_link, created_at, updated_at, cache_scope, cache_page, cache_page_size) SELECT id, content, tags, pinned_order, is_ad, extension, status, guild_id, channel_id, message_id, message_link, created_at, updated_at, cache_scope, cache_page, cache_page_size FROM moments_v4',
    'DROP TABLE moments_v4',
    'CREATE INDEX moments_cache_lookup_idx ON moments(cache_scope, cache_page, cache_page_size)',
    'ALTER TABLE moment_media RENAME TO moment_media_v4',
    'CREATE TABLE moment_media (id INTEGER NOT NULL, moment_id TEXT NOT NULL, name TEXT NOT NULL DEFAULT \'\', media_url TEXT NOT NULL, media_type TEXT NOT NULL, is_local INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0, cache_scope TEXT NOT NULL DEFAULT \'guest\', cache_page INTEGER NOT NULL DEFAULT 1, cache_page_size INTEGER NOT NULL DEFAULT 10, PRIMARY KEY (id, cache_scope, cache_page, cache_page_size))',
    'INSERT INTO moment_media (id, moment_id, name, media_url, media_type, is_local, is_deleted) SELECT id, moment_id, name, media_url, media_type, is_local, is_deleted FROM moment_media_v4',
    'DROP TABLE moment_media_v4',
    'ALTER TABLE moment_reactions RENAME TO moment_reactions_v4',
    'CREATE TABLE moment_reactions (id INTEGER NOT NULL, moment_id TEXT NOT NULL, fingerprint_id INTEGER NOT NULL, reaction TEXT NOT NULL, created_at INTEGER NOT NULL, cache_scope TEXT NOT NULL DEFAULT \'guest\', cache_page INTEGER NOT NULL DEFAULT 1, cache_page_size INTEGER NOT NULL DEFAULT 10, PRIMARY KEY (id, cache_scope, cache_page, cache_page_size), UNIQUE(moment_id, fingerprint_id, reaction, cache_scope, cache_page, cache_page_size))',
    'INSERT INTO moment_reactions (id, moment_id, fingerprint_id, reaction, created_at) SELECT id, moment_id, fingerprint_id, reaction, created_at FROM moment_reactions_v4',
    'DROP TABLE moment_reactions_v4',
  ],
  6: [
    'CREATE TABLE IF NOT EXISTS friend_link_cache (cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)',
  ],
  7: [
    'ALTER TABLE friend_links ADD COLUMN status TEXT NOT NULL DEFAULT \'\'',
  ],
  8: [
    'CREATE TABLE rss_feed_cache (cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)',
    'CREATE TABLE rss_post_cache (cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)',
    'CREATE TABLE image_cache (cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)',
  ],
};
