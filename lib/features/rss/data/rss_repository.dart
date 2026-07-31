import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../data/db/app_database.dart';
import 'rss_api.dart';

class RssRepository {
  const RssRepository({required this.api, required this.database});
  final RssApi api;
  final AppDatabase database;

  Future<RssPage<RssFeedDto>> feeds({int page = 1, int pageSize = 20, String? status}) async {
    final db = await database.database;
    final key = '$page:$pageSize:${status ?? ''}';
    final rows = await db.query('rss_feed_cache', where: 'cache_key = ?', whereArgs: [key]);
    if (rows.isNotEmpty) {
      final result = _feedPage(jsonDecode(rows.single['payload']! as String) as Map<String, dynamic>);
      _refreshFeeds(key, page: page, pageSize: pageSize, status: status);
      return result;
    }
    final result = await api.listFeeds(page: page, pageSize: pageSize, status: status);
    await _writeFeed(db, key, result);
    return result;
  }

  Future<RssPage<RssPostDto>> posts({int? rssId, int page = 1, int pageSize = 20}) async {
    final db = await database.database;
    final key = '${rssId ?? 0}:$page:$pageSize';
    final rows = await db.query('rss_post_cache', where: 'cache_key = ?', whereArgs: [key]);
    if (rows.isNotEmpty) return _postPage(jsonDecode(rows.single['payload']! as String) as Map<String, dynamic>);
    final result = await api.listPosts(rssId: rssId, page: page, pageSize: pageSize);
    await db.insert('rss_post_cache', {'cache_key': key, 'payload': jsonEncode({'items': result.items.map((e) => e.toJson()).toList(), 'total': result.total, 'page': result.page, 'page_size': result.pageSize},), 'updated_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
    return result;
  }

  Future<void> refresh() async { await api.refresh(); await clearCache(); }
  Future<void> clearCache() async { final db = await database.database; await db.delete('rss_feed_cache'); await db.delete('rss_post_cache'); }
  Future<void> create(RssFeedPayload payload) async { await api.create(payload); await clearCache(); }
  Future<void> update(int id, RssFeedPayload payload) async { await api.update(id, payload); await clearCache(); }
  Future<void> delete(int id) async { await api.delete(id); await clearCache(); }
  Future<RssFetchResult> fetch(int id) async { final result = await api.fetch(id); await clearCache(); return result; }
  Future<void> deletePost(int id) async { await api.deletePost(id); await clearCache(); }

  Future<void> _refreshFeeds(String key, {required int page, required int pageSize, String? status}) async { try { final result = await api.listFeeds(page: page, pageSize: pageSize, status: status); await _writeFeed(await database.database, key, result); } catch (_) {} }
  Future<void> _writeFeed(Database db, String key, RssPage<RssFeedDto> page) => db.insert('rss_feed_cache', {'cache_key': key, 'payload': jsonEncode({'items': page.items.map((e) => e.toJson()).toList(), 'total': page.total, 'page': page.page, 'page_size': page.pageSize},), 'updated_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
}

RssPage<RssFeedDto> _feedPage(Map<String, dynamic> json) => RssPage(items: (json['items'] as List).map((e) => RssFeedDto.fromJson(Map<String, dynamic>.from(e as Map))).toList(), total: (json['total'] as num).toInt(), page: (json['page'] as num).toInt(), pageSize: (json['page_size'] as num).toInt());
RssPage<RssPostDto> _postPage(Map<String, dynamic> json) => RssPage(items: (json['items'] as List).map((e) => RssPostDto.fromJson(Map<String, dynamic>.from(e as Map))).toList(), total: (json['total'] as num).toInt(), page: (json['page'] as num).toInt(), pageSize: (json['page_size'] as num).toInt());
